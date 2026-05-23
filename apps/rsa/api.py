from decimal import Decimal
from typing import Literal

from django.contrib.auth import get_user_model
from django.db.models import QuerySet
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.rider_auth.api import current_user_dep
from apps.rsa.models import RSATicket, RSATicketHistory
from apps.vehicle.models import Vehicle

router = APIRouter(prefix="/rsa", tags=["RSA"])
User = get_user_model()


class RSATicketCreateIn(BaseModel):
    phone_number: str = Field(default="", max_length=20)
    alternate_phone_number: str = Field(default="", max_length=20)
    region: str = Field(min_length=2, max_length=80)
    issue: str = Field(min_length=2, max_length=80)
    description: str = Field(default="", max_length=2000)
    gps_latitude: float | None = Field(default=None, ge=-90, le=90)
    gps_longitude: float | None = Field(default=None, ge=-180, le=180)
    metadata: dict = Field(default_factory=dict)


class RSATicketOut(BaseModel):
    id: int
    user_id: int
    vehicle_id: int | None
    phone_number: str
    alternate_phone_number: str
    region: str
    issue: str
    description: str
    gps_latitude: float | None
    gps_longitude: float | None
    status: Literal["new", "assigned", "in_progress", "resolved", "cancelled"]
    assigned_to_name: str
    admin_notes: str
    created_at: str
    updated_at: str
    resolved_at: str | None
    metadata: dict


class RSATicketListOut(BaseModel):
    total: int
    items: list[RSATicketOut]


class RSATicketHistoryOut(BaseModel):
    id: int
    ticket_id: int
    user_id: int | None
    status: str
    from_status: str
    to_status: str
    note: str
    created_at: str
    metadata: dict


class RSATicketDetailOut(RSATicketOut):
    history: list[RSATicketHistoryOut]


def _decimal_or_none(value: float | None) -> Decimal | None:
    if value is None:
        return None
    return Decimal(str(value))


def _ticket_out(ticket: RSATicket) -> RSATicketOut:
    return RSATicketOut(
        id=ticket.id,
        user_id=ticket.user_id,
        vehicle_id=ticket.vehicle_id,
        phone_number=ticket.phone_number or "",
        alternate_phone_number=ticket.alternate_phone_number or "",
        region=ticket.region,
        issue=ticket.issue,
        description=ticket.description or "",
        gps_latitude=float(ticket.gps_latitude) if ticket.gps_latitude is not None else None,
        gps_longitude=float(ticket.gps_longitude) if ticket.gps_longitude is not None else None,
        status=ticket.status,
        assigned_to_name=ticket.assigned_to_name or "",
        admin_notes=ticket.admin_notes or "",
        created_at=ticket.created_at.isoformat(),
        updated_at=ticket.updated_at.isoformat(),
        resolved_at=ticket.resolved_at.isoformat() if ticket.resolved_at else None,
        metadata=ticket.metadata or {},
    )


def _history_out(row: RSATicketHistory) -> RSATicketHistoryOut:
    return RSATicketHistoryOut(
        id=row.id,
        ticket_id=row.ticket_id,
        user_id=row.user_id,
        status=row.status,
        from_status=row.from_status or "",
        to_status=row.to_status or "",
        note=row.note or "",
        created_at=row.created_at.isoformat(),
        metadata=row.metadata or {},
    )


def _ticket_detail_out(ticket: RSATicket) -> RSATicketDetailOut:
    data = _ticket_out(ticket).model_dump()
    data["history"] = [_history_out(row) for row in ticket.history.all()]
    return RSATicketDetailOut(**data)


def _tickets_for_user(user: User) -> QuerySet[RSATicket]:
    return RSATicket.objects.filter(user=user).select_related("vehicle").order_by("-created_at", "-id")


@router.post("/tickets", response_model=RSATicketOut)
def create_rsa_ticket(
    payload: RSATicketCreateIn,
    user: User = Depends(current_user_dep),
) -> RSATicketOut:
    vehicle = Vehicle.objects.filter(user=user).first()
    ticket = RSATicket.objects.create(
        user=user,
        vehicle=vehicle,
        phone_number=payload.phone_number.strip(),
        alternate_phone_number=payload.alternate_phone_number.strip(),
        region=payload.region.strip(),
        issue=payload.issue.strip(),
        description=payload.description.strip(),
        gps_latitude=_decimal_or_none(payload.gps_latitude),
        gps_longitude=_decimal_or_none(payload.gps_longitude),
        metadata=payload.metadata,
    )
    RSATicketHistory.objects.create(
        ticket=ticket,
        user=user,
        status=RSATicketHistory.Status.CREATED,
        to_status=ticket.status,
        note="RSA ticket created by rider.",
    )
    return _ticket_out(ticket)


@router.get("/tickets", response_model=RSATicketListOut)
def list_rsa_tickets(
    limit: int = 30,
    offset: int = 0,
    status_filter: str = "",
    user: User = Depends(current_user_dep),
) -> RSATicketListOut:
    limit = max(1, min(limit, 200))
    offset = max(0, offset)
    qs = _tickets_for_user(user)
    if status_filter:
        valid_statuses = {choice for choice, _ in RSATicket.Status.choices}
        if status_filter not in valid_statuses:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid RSA status.")
        qs = qs.filter(status=status_filter)
    total = qs.count()
    rows = list(qs[offset : offset + limit])
    return RSATicketListOut(total=total, items=[_ticket_out(row) for row in rows])


@router.get("/history", response_model=RSATicketListOut)
def rsa_history(
    limit: int = 30,
    offset: int = 0,
    user: User = Depends(current_user_dep),
) -> RSATicketListOut:
    return list_rsa_tickets(limit=limit, offset=offset, user=user)


@router.get("/tickets/{ticket_id}", response_model=RSATicketDetailOut)
def get_rsa_ticket(
    ticket_id: int,
    user: User = Depends(current_user_dep),
) -> RSATicketDetailOut:
    ticket = _tickets_for_user(user).filter(id=ticket_id).first()
    if ticket is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="RSA ticket not found.")
    return _ticket_detail_out(ticket)

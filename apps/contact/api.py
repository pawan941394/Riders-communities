from typing import Any

from django.contrib.auth import get_user_model
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.contact.models import ContactSubmission, InquiryIssue
from apps.rider_auth.api import current_user_dep
from apps.rider_auth.models import RiderProfile

router = APIRouter(prefix="/contact", tags=["Contact"])
User = get_user_model()


def _identity_from_user(user: User) -> tuple[str, str, str]:
    """Display name, email, phone snapshot from account + rider profile."""
    full = f"{user.first_name} {user.last_name}".strip()
    if not full:
        full = user.get_full_name().strip()
    if not full:
        full = user.username
    email = (user.email or "").strip().lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Your account has no email on file. Update your profile first.",
        )
    profile = RiderProfile.objects.filter(user=user).first()
    phone = (profile.phone_number or "").strip()[:20] if profile else ""
    return full, email, phone


def _tile_from_issue(row: InquiryIssue) -> dict[str, Any]:
    return {
        "slug": row.slug,
        "title": row.title,
        "subtitle": row.subtitle or "",
        "detailDescription": row.detail_description or "",
        "iconKey": row.icon_key or "",
    }


@router.get("/meta")
def contact_meta() -> dict[str, Any]:
    """Inquiry kinds, Help tiles, and EV hub tiles — all driven by InquiryIssue in admin."""
    base = (
        InquiryIssue.objects.filter(is_active=True)
        .order_by("sort_order", "title")
        .all()
    )
    kinds = [
        {
            "value": row.slug,
            "label": (row.list_label or row.title).strip(),
        }
        for row in base
    ]
    help_tiles = [_tile_from_issue(r) for r in base if r.show_in_help]
    ev_hub_tiles = [_tile_from_issue(r) for r in base if r.show_in_ev_hub]
    return {
        "inquiryKinds": kinds,
        "helpTiles": help_tiles,
        "evHubTiles": ev_hub_tiles,
    }


class ContactCreate(BaseModel):
    inquiry_kind: str = Field(min_length=1, max_length=32)
    message: str = Field(min_length=10, max_length=8000)


@router.post("/submissions", status_code=status.HTTP_201_CREATED)
def create_contact_submission(
    payload: ContactCreate,
    user: User = Depends(current_user_dep),
) -> dict[str, Any]:
    allowed = set(
        InquiryIssue.objects.filter(is_active=True).values_list("slug", flat=True)
    )
    if payload.inquiry_kind not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid inquiry_kind. Use GET /contact/meta for allowed values.",
        )
    full_name, email, phone = _identity_from_user(user)
    row = ContactSubmission.objects.create(
        user=user,
        inquiry_kind=payload.inquiry_kind,
        full_name=full_name,
        email=email,
        phone=phone,
        message=payload.message.strip(),
    )
    return {
        "ok": True,
        "id": row.id,
        "linkedUserId": user.id,
    }

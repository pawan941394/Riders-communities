import math
import re
from pathlib import Path
from typing import Literal

from django.contrib.auth import get_user_model
from django.db.models import Q
from django.conf import settings
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field

from apps.ev.kml_importer import import_kml
from apps.ev.models import BuyEvPlan, EvLocation, EvPlanInterest, RentEvPlan
from apps.rider_auth.api import current_user_dep

router = APIRouter(prefix="/ev", tags=["EV"])

User = get_user_model()

_CITY_LINE = re.compile(r"City:\s*([^<\n\r]+)", re.IGNORECASE)


def _ev_partner_image_url(request: Request | None, field) -> str | None:
    """Absolute URL for partner card images; matches API host (works with emulator / LAN)."""
    if not field or not getattr(field, "name", None):
        return None
    rel = field.url
    if request is not None:
        root = str(request.base_url).rstrip("/").removesuffix("/api/v1")
        return f"{root}{rel}"
    base = getattr(settings, "PUBLIC_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
    return f"{base}{rel}" if rel.startswith("/") else f"{base}/{rel}"


class EvLocationOut(BaseModel):
    id: int
    name: str
    description: str
    address: str
    latitude: float
    longitude: float
    source_name: str


class ImportKmlRequest(BaseModel):
    source_path: str
    source_name: str = "kml"


def _hex_to_flutter_argb(hex_str: str) -> int:
    """Convert #RRGGBB (or AARRGGBB) to Flutter-style Color int (opaque if 6-digit)."""
    s = (hex_str or "").strip().lstrip("#")
    if len(s) == 6:
        return int(s, 16) | 0xFF000000
    if len(s) == 8:
        return int(s, 16)
    return 0xFF000000


class BuyEvPlanOut(BaseModel):
    """JSON shape aligned with Flutter `BuyEvPlan` consumption."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(description="Stable slug, e.g. ampere_nexus")
    company_name: str = Field(serialization_alias="companyName")
    tagline: str
    ex_showroom_from: float = Field(serialization_alias="exShowroomFrom")
    documents_required: list[str] = Field(serialization_alias="documentsRequired")
    accent_a: int = Field(serialization_alias="accentA")
    accent_b: int = Field(serialization_alias="accentB")
    image_url: str | None = Field(default=None, serialization_alias="imageUrl")
    emi_available: bool = Field(serialization_alias="emiAvailable")
    down_payment_options_available: bool = Field(
        serialization_alias="downPaymentOptionsAvailable"
    )

    @classmethod
    def from_model(cls, row: BuyEvPlan, request: Request | None = None) -> "BuyEvPlanOut":
        return cls(
            id=row.slug,
            company_name=row.company_name,
            tagline=row.tagline,
            ex_showroom_from=float(row.ex_showroom_from),
            documents_required=list(row.documents_required or []),
            accent_a=_hex_to_flutter_argb(row.accent_a_hex),
            accent_b=_hex_to_flutter_argb(row.accent_b_hex),
            image_url=_ev_partner_image_url(request, row.partner_image),
            emi_available=row.emi_available,
            down_payment_options_available=row.down_payment_options_available,
        )


class RentEvPlanOut(BaseModel):
    """JSON aligned with Flutter `RentEvPlan`."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(description="Slug, e.g. hala")
    company_name: str = Field(serialization_alias="companyName")
    tagline: str
    security_deposit: float = Field(serialization_alias="securityDeposit")
    weekly_rent: float = Field(serialization_alias="weeklyRent")
    daily_rent: float = Field(serialization_alias="dailyRent")
    documents_required: list[str] = Field(serialization_alias="documentsRequired")
    accent_a: int = Field(serialization_alias="accentA")
    accent_b: int = Field(serialization_alias="accentB")
    featured: bool
    image_url: str | None = Field(default=None, serialization_alias="imageUrl")

    @classmethod
    def from_model(cls, row: RentEvPlan, request: Request | None = None) -> "RentEvPlanOut":
        return cls(
            id=row.slug,
            company_name=row.company_name,
            tagline=row.tagline,
            security_deposit=float(row.security_deposit),
            weekly_rent=float(row.weekly_rent),
            daily_rent=float(row.daily_rent),
            documents_required=list(row.documents_required or []),
            accent_a=_hex_to_flutter_argb(row.accent_a_hex),
            accent_b=_hex_to_flutter_argb(row.accent_b_hex),
            featured=row.featured,
            image_url=_ev_partner_image_url(request, row.partner_image),
        )


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlamb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlamb / 2) ** 2
    c = 2 * math.asin(min(1.0, math.sqrt(a)))
    return r * c


def _city_tokens(raw: str) -> list[str]:
    t = (raw or "").strip()
    if not t or t.lower() == "all":
        return []
    low = t.lower()
    out = {low, t}
    if "gurugram" in low or "gurgaon" in low:
        out.update({"gurugram", "gurgaon"})
    return list(out)


def _city_filter_q(city: str) -> Q:
    tokens = _city_tokens(city)
    if not tokens:
        return Q()
    q = Q()
    for tok in tokens:
        q |= Q(description__icontains=f"City: {tok}")
    return q


@router.get("/buy-plans", response_model=dict)
def list_buy_ev_plans(request: Request, search: str = "") -> dict:
    """Active purchase / finance partner rows for the Buy EV hub."""
    qs = BuyEvPlan.objects.filter(is_active=True).order_by("sort_order", "company_name", "slug")
    if search.strip():
        term = search.strip()
        qs = qs.filter(Q(company_name__icontains=term) | Q(tagline__icontains=term))
    items = [BuyEvPlanOut.from_model(row, request).model_dump(by_alias=True) for row in qs]
    return {"items": items, "total": len(items)}


@router.get("/buy-plans/{slug}", response_model=dict)
def get_buy_ev_plan(request: Request, slug: str) -> dict:
    row = BuyEvPlan.objects.filter(is_active=True, slug=slug.strip()).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Buy EV plan not found.")
    return BuyEvPlanOut.from_model(row, request).model_dump(by_alias=True)


@router.get("/rent-plans", response_model=dict)
def list_rent_ev_plans(request: Request, search: str = "") -> dict:
    qs = RentEvPlan.objects.filter(is_active=True).order_by("-featured", "sort_order", "company_name", "slug")
    if search.strip():
        term = search.strip()
        qs = qs.filter(Q(company_name__icontains=term) | Q(tagline__icontains=term))
    items = [RentEvPlanOut.from_model(row, request).model_dump(by_alias=True) for row in qs]
    return {"items": items, "total": len(items)}


@router.get("/rent-plans/{slug}", response_model=dict)
def get_rent_ev_plan(request: Request, slug: str) -> dict:
    row = RentEvPlan.objects.filter(is_active=True, slug=slug.strip()).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Rent EV plan not found.")
    return RentEvPlanOut.from_model(row, request).model_dump(by_alias=True)


class EvInterestIn(BaseModel):
    channel: Literal["buy", "rent"]
    plan_slug: str = Field(min_length=1, max_length=80)
    partner_label: str | None = Field(default=None, max_length=160)


@router.post("/interests", response_model=dict)
def create_ev_plan_interest(
    payload: EvInterestIn,
    user: User = Depends(current_user_dep),
) -> dict:
    """Record rider interest (buy or rent). Idempotent per user + channel + plan slug."""
    slug = payload.plan_slug.strip()
    if not slug:
        raise HTTPException(status_code=400, detail="plan_slug is required.")

    label = (payload.partner_label or "").strip()[:160]

    if payload.channel == "buy":
        plan = BuyEvPlan.objects.filter(slug=slug, is_active=True).first()
        if plan is None:
            raise HTTPException(status_code=404, detail="Buy EV plan not found or inactive.")
        label = plan.company_name
        EvPlanInterest.objects.update_or_create(
            user=user,
            channel=EvPlanInterest.Channel.BUY,
            buy_plan=plan,
            defaults={"partner_label": label, "plan_slug": None},
        )
        return {
            "ok": True,
            "channel": payload.channel,
            "planSlug": plan.slug,
            "buyPlanId": plan.id,
            "rentPlanId": None,
            "partnerLabel": label,
        }

    rplan = RentEvPlan.objects.filter(slug=slug, is_active=True).first()
    if rplan is None:
        raise HTTPException(status_code=404, detail="Rent EV plan not found or inactive.")
    label = rplan.company_name
    EvPlanInterest.objects.update_or_create(
        user=user,
        channel=EvPlanInterest.Channel.RENT,
        rent_plan=rplan,
        defaults={
            "partner_label": label,
            "buy_plan": None,
            "plan_slug": None,
        },
    )
    return {
        "ok": True,
        "channel": payload.channel,
        "planSlug": rplan.slug,
        "buyPlanId": None,
        "rentPlanId": rplan.id,
        "partnerLabel": label,
    }


@router.get("/cities")
def list_ev_cities() -> dict:
    seen: set[str] = set()
    for desc in EvLocation.objects.values_list("description", flat=True).iterator(chunk_size=256):
        if not desc:
            continue
        m = _CITY_LINE.search(desc)
        if m:
            seen.add(m.group(1).strip())
    return {"cities": sorted(seen, key=lambda s: s.casefold())}


@router.get("/locations")
def list_locations(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    search: str = "",
    city: str = "",
    near_lat: float | None = Query(default=None),
    near_lon: float | None = Query(default=None),
) -> dict:
    queryset = EvLocation.objects.all()
    if search.strip():
        term = search.strip()
        queryset = queryset.filter(Q(name__icontains=term) | Q(address__icontains=term))
    if city.strip() and city.strip().lower() != "all":
        queryset = queryset.filter(_city_filter_q(city))

    rows = list(queryset.values("id", "latitude", "longitude"))
    total = len(rows)

    if near_lat is not None and near_lon is not None:
        rows.sort(
            key=lambda r: _haversine_km(near_lat, near_lon, float(r["latitude"]), float(r["longitude"]))
        )
    else:
        rows.sort(key=lambda r: (r["id"],))

    page_rows = rows[offset : offset + limit]
    id_order = [int(r["id"]) for r in page_rows]
    bulk = EvLocation.objects.in_bulk(id_order)
    items = []
    for pk in id_order:
        obj = bulk.get(pk)
        if obj is None:
            continue
        items.append(
            {
                "id": obj.id,
                "name": obj.name,
                "description": obj.description,
                "address": obj.address,
                "latitude": obj.latitude,
                "longitude": obj.longitude,
                "source_name": obj.source_name,
            }
        )

    return {"total": total, "limit": limit, "offset": offset, "items": items}


@router.post("/import-kml")
def import_kml_endpoint(payload: ImportKmlRequest) -> dict:
    source = payload.source_path.strip()
    if not source:
        raise HTTPException(status_code=400, detail="source_path is required.")
    result = import_kml(source=source, source_name=payload.source_name.strip() or "kml")
    return {"message": "KML import completed.", **result}


@router.post("/import-default-kml")
def import_default_kml() -> dict:
    default_path = Path(__file__).resolve().parents[3] / "NCR.kml"
    if not default_path.exists():
        raise HTTPException(status_code=404, detail="NCR.kml not found at project root.")
    result = import_kml(source=str(default_path), source_name="NCR")
    return {"message": "Default KML import completed.", **result}

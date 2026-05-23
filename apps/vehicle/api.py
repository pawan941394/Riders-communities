from typing import Literal

from django.contrib.auth import get_user_model
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.rider_auth.api import current_user_dep
from apps.vehicle.models import Vehicle

router = APIRouter(prefix="/vehicle", tags=["Vehicle"])
User = get_user_model()


class VehicleIn(BaseModel):
    vehicle_type: Literal["ev_scooter", "ev_bike", "bike", "scooter", "other"] = Field(...)
    company_name: str = Field(default="", max_length=120)
    model_name: str = Field(default="", max_length=120)
    registration_number: str = Field(default="", max_length=40)
    chassis_number: str = Field(default="", max_length=80)
    battery_number: str = Field(default="", max_length=80)
    color: str = Field(default="", max_length=60)
    purchase_year: int | None = Field(default=None, ge=1990, le=2100)
    is_active: bool = True
    metadata: dict = Field(default_factory=dict)


class VehicleOut(BaseModel):
    id: int
    user_id: int
    vehicle_type: str
    company_name: str
    model_name: str
    registration_number: str
    chassis_number: str
    battery_number: str
    color: str
    purchase_year: int | None
    is_active: bool
    metadata: dict
    created_at: str
    updated_at: str


class VehicleMeResponse(BaseModel):
    vehicle: VehicleOut | None


def _clean(value: str) -> str:
    return value.strip()


def _required(value: str, field_name: str) -> str:
    cleaned = _clean(value)
    if not cleaned:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} is required.",
        )
    return cleaned


def _vehicle_out(vehicle: Vehicle) -> VehicleOut:
    return VehicleOut(
        id=vehicle.id,
        user_id=vehicle.user_id,
        vehicle_type=vehicle.vehicle_type,
        company_name=vehicle.company_name or "",
        model_name=vehicle.model_name or "",
        registration_number=vehicle.registration_number or "",
        chassis_number=vehicle.chassis_number or "",
        battery_number=vehicle.battery_number or "",
        color=vehicle.color or "",
        purchase_year=vehicle.purchase_year,
        is_active=vehicle.is_active,
        metadata=vehicle.metadata or {},
        created_at=vehicle.created_at.isoformat(),
        updated_at=vehicle.updated_at.isoformat(),
    )


@router.get("/me", response_model=VehicleMeResponse)
def vehicle_me(user: User = Depends(current_user_dep)) -> VehicleMeResponse:
    vehicle = Vehicle.objects.filter(user=user).first()
    return VehicleMeResponse(vehicle=_vehicle_out(vehicle) if vehicle else None)


@router.put("/me", response_model=VehicleMeResponse)
def upsert_vehicle(
    payload: VehicleIn,
    user: User = Depends(current_user_dep),
) -> VehicleMeResponse:
    model_name = _clean(payload.model_name)
    registration_number = _required(payload.registration_number, "Vehicle number").upper()
    chassis_number = _clean(payload.chassis_number).upper()
    company_name = _required(payload.company_name, "Rider company")
    battery_number = _clean(payload.battery_number).upper()

    vehicle, _ = Vehicle.objects.get_or_create(user=user)
    vehicle.vehicle_type = payload.vehicle_type
    vehicle.company_name = company_name
    vehicle.model_name = model_name
    vehicle.registration_number = registration_number
    vehicle.chassis_number = chassis_number
    vehicle.battery_number = battery_number
    vehicle.color = _clean(payload.color)
    vehicle.purchase_year = payload.purchase_year
    vehicle.is_active = payload.is_active
    vehicle.metadata = payload.metadata
    vehicle.save()
    return VehicleMeResponse(vehicle=_vehicle_out(vehicle))


@router.delete("/me", response_model=VehicleMeResponse)
def delete_vehicle(user: User = Depends(current_user_dep)) -> VehicleMeResponse:
    deleted, _ = Vehicle.objects.filter(user=user).delete()
    if deleted == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found.")
    return VehicleMeResponse(vehicle=None)

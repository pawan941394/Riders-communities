from django.contrib.auth import get_user_model
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from apps.referral.models import ReferralCode
from apps.referral.services import (
    ReferralApplyError,
    apply_referral_code_for_user,
    generate_unique_referral_code,
)
from apps.rider_auth.api import current_user_dep

router = APIRouter(prefix="/referral", tags=["Referral"])
User = get_user_model()


class ReferralMeOut(BaseModel):
    user_id: int
    referral_code: str


class ReferralApplyIn(BaseModel):
    referral_code: str = Field(min_length=3, max_length=24)


class ReferralApplyOut(BaseModel):
    ok: bool
    referred_user_id: int
    referrer_user_id: int
    referral_code: str
    reward_credits: int
    channel: str


@router.get("/me", response_model=ReferralMeOut)
def referral_me(user: User = Depends(current_user_dep)) -> ReferralMeOut:
    row, _ = ReferralCode.objects.get_or_create(
        user=user,
        defaults={"code": generate_unique_referral_code()},
    )
    return ReferralMeOut(user_id=user.id, referral_code=row.code)


@router.post("/apply", response_model=ReferralApplyOut)
def referral_apply(
    payload: ReferralApplyIn,
    user: User = Depends(current_user_dep),
) -> ReferralApplyOut:
    try:
        result = apply_referral_code_for_user(
            referred_user=user,
            referral_code=payload.referral_code,
            channel="manual",
        )
    except ReferralApplyError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    return ReferralApplyOut(
        ok=True,
        referred_user_id=user.id,
        referrer_user_id=result.referrer_user_id,
        referral_code=result.referrer_code,
        reward_credits=result.reward_credits,
        channel=result.channel,
    )

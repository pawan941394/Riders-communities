import secrets
import string
from dataclasses import dataclass

from django.contrib.auth import get_user_model
from django.db import transaction

from apps.referral.models import (
    ReferralCode,
    ReferralRedemption,
    ReferralRewardConfig,
)
from apps.rider_auth.models import RiderProfile
from apps.wallet.models import Wallet, WalletTransaction

User = get_user_model()

_ALPHABET = string.ascii_uppercase + string.digits
_PREFIX = "RWG"


class ReferralApplyError(Exception):
    pass


@dataclass(slots=True)
class ReferralApplyResult:
    referrer_user_id: int
    referrer_code: str
    reward_credits: int
    channel: str


def generate_referral_code() -> str:
    return f"{_PREFIX}{''.join(secrets.choice(_ALPHABET) for _ in range(8))}"


def generate_unique_referral_code() -> str:
    for _ in range(50):
        code = generate_referral_code()
        if not ReferralCode.objects.filter(code=code).exists():
            return code
    raise RuntimeError("Could not generate a unique referral code.")


def _user_identity_snapshot(user: User) -> dict[str, str | int]:
    full_name = f"{user.first_name} {user.last_name}".strip() or user.username
    email = (user.email or "").strip().lower()
    phone = ""
    city = ""
    profile = RiderProfile.objects.filter(user=user).first()
    if profile is not None:
        phone = (profile.phone_number or "").strip()
        city = (profile.city or "").strip()
    return {
        "id": user.id,
        "username": user.username,
        "full_name": full_name,
        "email": email,
        "phone_number": phone,
        "city": city,
    }


def apply_referral_code_for_user(
    *,
    referred_user: User,
    referral_code: str,
    channel: str,
) -> ReferralApplyResult:
    referral_code_clean = (referral_code or "").strip().upper()
    if not referral_code_clean:
        raise ReferralApplyError("Referral code is required.")

    with transaction.atomic():
        if ReferralRedemption.objects.select_for_update().filter(referred_user=referred_user).exists():
            raise ReferralApplyError("You have already used a referral code.")

        code_row = (
            ReferralCode.objects.select_for_update()
            .select_related("user")
            .filter(code__iexact=referral_code_clean)
            .first()
        )
        if code_row is None:
            raise ReferralApplyError("Invalid referral code.")

        if code_row.user_id == referred_user.id:
            raise ReferralApplyError("You cannot use your own referral code.")

        reward_cfg, _ = ReferralRewardConfig.objects.get_or_create(
            key=ReferralRewardConfig.DEFAULT_KEY,
        )
        reward_amount = int(reward_cfg.referral_amount_credits or 0)

        referrer_user = code_row.user
        if reward_amount > 0:
            ref_wallet = Wallet.objects.select_for_update().filter(user=referrer_user).first()
            if ref_wallet is None:
                ref_wallet = Wallet.objects.create(user=referrer_user)
            before = ref_wallet.balance_credits
            after = before + reward_amount
            ref_wallet.balance_credits = after
            ref_wallet.lifetime_credited = ref_wallet.lifetime_credited + reward_amount
            ref_wallet.save(update_fields=["balance_credits", "lifetime_credited", "updated_at"])

            referred_meta = _user_identity_snapshot(referred_user)
            WalletTransaction.objects.create(
                wallet=ref_wallet,
                user=referrer_user,
                created_by=referred_user,
                entry_type=WalletTransaction.EntryType.CREDIT,
                amount=reward_amount,
                balance_before=before,
                balance_after=after,
                source="referral_reward",
                reason="Referral reward credited.",
                reference_id=f"{channel}:{referred_user.id}",
                metadata={
                    "referral_code": code_row.code,
                    "channel": channel,
                    "referred_user": referred_meta,
                },
            )

        ReferralRedemption.objects.create(
            referred_user=referred_user,
            referrer_user=referrer_user,
            referral_code=code_row,
            reward_credits=reward_amount,
            channel=channel,
        )

    return ReferralApplyResult(
        referrer_user_id=referrer_user.id,
        referrer_code=code_row.code,
        reward_credits=reward_amount,
        channel=channel,
    )


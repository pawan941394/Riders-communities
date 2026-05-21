from django.contrib.auth import get_user_model
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.referral.models import ReferralCode
from apps.referral.services import generate_unique_referral_code
from apps.wallet.models import Wallet

User = get_user_model()


@receiver(post_save, sender=User)
def ensure_wallet_and_referral_for_user(sender, instance: User, created: bool, **kwargs) -> None:
    if not created:
        return
    Wallet.objects.get_or_create(user=instance)
    ReferralCode.objects.get_or_create(
        user=instance,
        defaults={"code": generate_unique_referral_code()},
    )


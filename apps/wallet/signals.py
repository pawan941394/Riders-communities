from django.contrib.auth import get_user_model
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.wallet.models import Wallet

User = get_user_model()


@receiver(post_save, sender=User)
def ensure_wallet_for_user(sender, instance: User, created: bool, **kwargs) -> None:
    if not created:
        return
    Wallet.objects.get_or_create(user=instance)


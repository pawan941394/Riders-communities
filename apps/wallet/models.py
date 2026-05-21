from django.conf import settings
from django.db import models


class Wallet(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="wallet",
    )
    balance_credits = models.PositiveBigIntegerField(default=0)
    lifetime_credited = models.PositiveBigIntegerField(default=0)
    lifetime_debited = models.PositiveBigIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at",)

    def __str__(self) -> str:
        return f"Wallet(user_id={self.user_id}, balance={self.balance_credits})"


class WalletTransaction(models.Model):
    class EntryType(models.TextChoices):
        CREDIT = "credit", "Credit"
        DEBIT = "debit", "Debit"

    wallet = models.ForeignKey(
        Wallet,
        on_delete=models.CASCADE,
        related_name="transactions",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="wallet_transactions",
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="wallet_transactions_created",
    )
    entry_type = models.CharField(max_length=8, choices=EntryType.choices)
    amount = models.PositiveBigIntegerField()
    balance_before = models.PositiveBigIntegerField()
    balance_after = models.PositiveBigIntegerField()
    source = models.CharField(
        max_length=64,
        help_text="Where this change came from: admin, referral, order, refund, etc.",
    )
    reason = models.CharField(max_length=255, blank=True, default="")
    reference_id = models.CharField(max_length=128, blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["wallet", "-created_at"]),
            models.Index(fields=["source"]),
        ]

    def __str__(self) -> str:
        return (
            f"WalletTransaction(wallet_id={self.wallet_id}, type={self.entry_type}, "
            f"amount={self.amount}, after={self.balance_after})"
        )


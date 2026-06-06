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


class WalletWithdrawalRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PROCESSING = "processing", "Processing"
        PAID = "paid", "Paid"
        REJECTED = "rejected", "Rejected"

    wallet = models.ForeignKey(
        Wallet,
        on_delete=models.CASCADE,
        related_name="withdrawal_requests",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="wallet_withdrawal_requests",
    )
    debit_transaction = models.OneToOneField(
        WalletTransaction,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="withdrawal_request",
    )
    amount = models.PositiveBigIntegerField()
    upi_id = models.CharField(max_length=128)
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
    )
    user_note = models.CharField(max_length=255, blank=True, default="")
    admin_note = models.CharField(max_length=255, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Wallet withdrawal request"
        verbose_name_plural = "Wallet withdrawal requests"
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["status", "-created_at"]),
            models.Index(fields=["upi_id"]),
        ]

    def __str__(self) -> str:
        return (
            f"WalletWithdrawalRequest(user_id={self.user_id}, amount={self.amount}, "
            f"status={self.status})"
        )


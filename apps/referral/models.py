from django.conf import settings
from django.db import models


class ReferralCode(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="referral_code",
    )
    code = models.CharField(max_length=24, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"{self.user_id}:{self.code}"


class ReferralRewardConfig(models.Model):
    DEFAULT_KEY = "default"

    key = models.CharField(max_length=32, unique=True, default=DEFAULT_KEY, editable=False)
    referral_amount_credits = models.PositiveBigIntegerField(
        default=0,
        help_text="Credits rewarded to the owner of a valid referral code on successful signup.",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Referral Reward Config"
        verbose_name_plural = "Referral Reward Config"

    def __str__(self) -> str:
        return f"ReferralRewardConfig(amount={self.referral_amount_credits})"


class ReferralRedemption(models.Model):
    class Channel(models.TextChoices):
        SIGNUP = "signup", "Signup"
        MANUAL = "manual", "Manual"

    referred_user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="referral_redemption",
    )
    referrer_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="referrals_sent",
    )
    referral_code = models.ForeignKey(
        ReferralCode,
        on_delete=models.PROTECT,
        related_name="redemptions",
    )
    reward_credits = models.PositiveBigIntegerField(default=0)
    channel = models.CharField(max_length=12, choices=Channel.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["referrer_user", "-created_at"]),
            models.Index(fields=["channel"]),
        ]

    def __str__(self) -> str:
        return (
            f"ReferralRedemption(referred={self.referred_user_id}, "
            f"referrer={self.referrer_user_id}, code={self.referral_code.code})"
        )

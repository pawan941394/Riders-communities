from django.contrib import admin

from apps.referral.models import (
    ReferralCode,
    ReferralRedemption,
    ReferralRewardConfig,
)


@admin.register(ReferralCode)
class ReferralCodeAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "code", "created_at")
    search_fields = ("code", "user__username", "user__email")
    readonly_fields = ("created_at", "updated_at")


@admin.register(ReferralRewardConfig)
class ReferralRewardConfigAdmin(admin.ModelAdmin):
    list_display = ("id", "key", "referral_amount_credits", "updated_at")
    readonly_fields = ("key", "updated_at")

    def has_add_permission(self, request):
        return not ReferralRewardConfig.objects.exists()


@admin.register(ReferralRedemption)
class ReferralRedemptionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "referred_user",
        "referrer_user",
        "referral_code",
        "reward_credits",
        "channel",
        "created_at",
    )
    list_filter = ("channel", "created_at")
    search_fields = (
        "referred_user__username",
        "referrer_user__username",
        "referral_code__code",
    )

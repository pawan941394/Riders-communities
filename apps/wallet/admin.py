from django.contrib import admin

from apps.wallet.models import Wallet, WalletTransaction


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "balance_credits",
        "lifetime_credited",
        "lifetime_debited",
        "updated_at",
    )
    search_fields = ("user__username", "user__email", "user__first_name", "user__last_name")
    readonly_fields = ("created_at", "updated_at")


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "wallet",
        "entry_type",
        "amount",
        "balance_before",
        "balance_after",
        "source",
        "created_at",
    )
    list_filter = ("entry_type", "source", "created_at")
    search_fields = ("wallet__user__username", "reason", "reference_id")
    readonly_fields = ("created_at",)


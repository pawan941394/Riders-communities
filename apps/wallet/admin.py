from django.contrib import admin

from apps.wallet.models import Wallet, WalletTransaction, WalletWithdrawalRequest


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


@admin.register(WalletWithdrawalRequest)
class WalletWithdrawalRequestAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "amount",
        "upi_id",
        "status",
        "created_at",
        "processed_at",
    )
    list_filter = ("status", "created_at", "processed_at")
    search_fields = (
        "user__username",
        "user__email",
        "user__first_name",
        "user__last_name",
        "upi_id",
        "user_note",
        "admin_note",
    )
    readonly_fields = (
        "wallet",
        "user",
        "debit_transaction",
        "amount",
        "upi_id",
        "user_note",
        "created_at",
        "updated_at",
    )

    def has_module_permission(self, request):
        return bool(request.user and request.user.is_active and request.user.is_staff)

    def has_view_permission(self, request, obj=None):
        return bool(request.user and request.user.is_active and request.user.is_staff)

    def has_change_permission(self, request, obj=None):
        return bool(request.user and request.user.is_active and request.user.is_staff)

    def has_add_permission(self, request):
        return False

    def get_model_perms(self, request):
        if not self.has_module_permission(request):
            return {}
        return {
            "add": False,
            "change": True,
            "delete": False,
            "view": True,
        }


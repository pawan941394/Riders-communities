from django.contrib import admin

from .models import RSATicket, RSATicketHistory


class RSATicketHistoryInline(admin.TabularInline):
    model = RSATicketHistory
    extra = 0
    readonly_fields = (
        "user",
        "status",
        "from_status",
        "to_status",
        "note",
        "metadata",
        "created_at",
    )
    can_delete = False


@admin.register(RSATicket)
class RSATicketAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "phone_number",
        "region",
        "issue",
        "status",
        "payment_status",
        "created_at",
    )
    list_filter = ("status", "region", "issue", "created_at")
    search_fields = (
        "user__username",
        "user__email",
        "phone_number",
        "alternate_phone_number",
        "region",
        "issue",
        "description",
    )
    readonly_fields = ("created_at", "updated_at")
    inlines = (RSATicketHistoryInline,)
    fieldsets = (
        (
            "Rider",
            {
                "fields": (
                    "user",
                    "vehicle",
                    "phone_number",
                    "alternate_phone_number",
                )
            },
        ),
        (
            "Ticket",
            {
                "fields": (
                    "region",
                    "issue",
                    "description",
                    "gps_latitude",
                    "gps_longitude",
                    "status",
                    "assigned_to_name",
                    "admin_notes",
                    "payment_link",
                    "payment_status",
                    "resolved_at",
                    "metadata",
                )
            },
        ),
        ("Timestamps", {"fields": ("created_at", "updated_at")}),
    )


@admin.register(RSATicketHistory)
class RSATicketHistoryAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "ticket",
        "user",
        "status",
        "from_status",
        "to_status",
        "created_at",
    )
    list_filter = ("status", "from_status", "to_status", "created_at")
    search_fields = (
        "ticket__id",
        "user__username",
        "user__email",
        "note",
    )
    readonly_fields = ("created_at",)

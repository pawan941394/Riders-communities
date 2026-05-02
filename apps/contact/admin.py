from django.contrib import admin

from .models import ContactSubmission, InquiryIssue


@admin.register(InquiryIssue)
class InquiryIssueAdmin(admin.ModelAdmin):
    list_display = (
        "slug",
        "title",
        "sort_order",
        "is_active",
        "show_in_help",
        "show_in_ev_hub",
    )
    list_filter = ("is_active", "show_in_help", "show_in_ev_hub")
    search_fields = ("slug", "title", "subtitle")
    ordering = ("sort_order", "title")


@admin.register(ContactSubmission)
class ContactSubmissionAdmin(admin.ModelAdmin):
    list_display = (
        "inquiry_kind",
        "full_name",
        "email",
        "phone",
        "user",
        "created_at",
    )
    list_filter = ("inquiry_kind", "created_at")
    search_fields = ("full_name", "email", "phone", "message")
    readonly_fields = ("created_at",)
    raw_id_fields = ("user",)
    date_hierarchy = "created_at"

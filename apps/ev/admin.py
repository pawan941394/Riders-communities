from django.contrib import admin

from .models import BuyEvPlan, EvLocation, EvPlanInterest, RentEvPlan


class EvPlanInterestInline(admin.TabularInline):
    model = EvPlanInterest
    fk_name = "buy_plan"
    extra = 0
    readonly_fields = ("user", "channel", "partner_label", "created_at", "updated_at")
    raw_id_fields = ("user",)
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


class EvRentInterestInline(admin.TabularInline):
    model = EvPlanInterest
    fk_name = "rent_plan"
    extra = 0
    readonly_fields = ("user", "channel", "partner_label", "created_at", "updated_at")
    raw_id_fields = ("user",)
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(EvPlanInterest)
class EvPlanInterestAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "channel",
        "buy_plan",
        "rent_plan",
        "plan_slug",
        "partner_label",
        "updated_at",
    )
    list_filter = ("channel",)
    list_select_related = ("buy_plan", "rent_plan")
    search_fields = (
        "plan_slug",
        "partner_label",
        "buy_plan__slug",
        "buy_plan__company_name",
        "rent_plan__slug",
        "rent_plan__company_name",
        "user__email",
        "user__username",
    )
    readonly_fields = ("created_at", "updated_at")
    raw_id_fields = ("user", "buy_plan", "rent_plan")


@admin.register(BuyEvPlan)
class BuyEvPlanAdmin(admin.ModelAdmin):
    fields = (
        "slug",
        "company_name",
        "tagline",
        "partner_image",
        "ex_showroom_from",
        "documents_required",
        "accent_a_hex",
        "accent_b_hex",
        "emi_available",
        "down_payment_options_available",
        "sort_order",
        "is_active",
        "created_at",
        "updated_at",
    )
    readonly_fields = ("created_at", "updated_at")
    list_display = (
        "company_name",
        "slug",
        "ex_showroom_from",
        "emi_available",
        "down_payment_options_available",
        "is_active",
        "sort_order",
        "updated_at",
    )
    list_filter = ("is_active", "emi_available", "down_payment_options_available")
    search_fields = ("company_name", "slug", "tagline")
    ordering = ("sort_order", "company_name")
    inlines = (EvPlanInterestInline,)


@admin.register(RentEvPlan)
class RentEvPlanAdmin(admin.ModelAdmin):
    fields = (
        "slug",
        "company_name",
        "tagline",
        "partner_image",
        "security_deposit",
        "weekly_rent",
        "daily_rent",
        "documents_required",
        "accent_a_hex",
        "accent_b_hex",
        "featured",
        "sort_order",
        "is_active",
        "created_at",
        "updated_at",
    )
    readonly_fields = ("created_at", "updated_at")
    list_display = (
        "company_name",
        "slug",
        "security_deposit",
        "weekly_rent",
        "daily_rent",
        "featured",
        "is_active",
        "sort_order",
        "updated_at",
    )
    list_filter = ("is_active", "featured")
    search_fields = ("company_name", "slug", "tagline")
    ordering = ("sort_order", "company_name")
    inlines = (EvRentInterestInline,)


@admin.register(EvLocation)
class EvLocationAdmin(admin.ModelAdmin):
    list_display = ("name", "address", "latitude", "longitude", "source_name", "updated_at")
    search_fields = ("name", "address", "source_name", "source_url")
    list_filter = ("source_name", "geometry_type", "updated_at")

from django.contrib import admin

from .models import Vehicle


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "vehicle_type",
        "company_name",
        "model_name",
        "registration_number",
        "chassis_number",
        "is_active",
        "updated_at",
    )
    list_filter = ("vehicle_type", "is_active", "company_name")
    search_fields = (
        "user__username",
        "user__email",
        "company_name",
        "model_name",
        "registration_number",
        "chassis_number",
        "battery_number",
    )
    readonly_fields = ("created_at", "updated_at")

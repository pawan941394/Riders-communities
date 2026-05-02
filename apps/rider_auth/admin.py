from django.contrib import admin
from .models import RiderProfile


@admin.register(RiderProfile)
class RiderProfileAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "phone_number",
        "rider_company",
        "is_phone_verified",
        "created_at",
    )
    search_fields = ("user__email", "user__username", "phone_number", "rider_company")
    list_filter = ("is_phone_verified", "preferred_language", "rider_company", "created_at")

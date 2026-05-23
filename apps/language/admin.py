from django.contrib import admin

from apps.language.models import UserLanguage


@admin.register(UserLanguage)
class UserLanguageAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "language_code", "updated_at")
    list_filter = ("language_code", "updated_at")
    search_fields = ("user__username", "user__email", "language_code")
    readonly_fields = ("created_at", "updated_at")

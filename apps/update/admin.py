from django.contrib import admin

from apps.update.models import AppVersionConfig


@admin.register(AppVersionConfig)
class AppVersionConfigAdmin(admin.ModelAdmin):
    list_display = ("id", "key", "version_name", "updated_at")
    readonly_fields = ("key", "updated_at")

    def has_add_permission(self, request):
        return not AppVersionConfig.objects.exists()

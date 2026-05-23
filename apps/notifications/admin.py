from django.contrib import admin

from apps.notifications.models import (
    BroadcastNotification,
    PushDeviceToken,
    UserNotificationState,
)


@admin.register(BroadcastNotification)
class BroadcastNotificationAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "is_active", "created_at", "updated_at")
    list_filter = ("is_active", "created_at")
    search_fields = ("title", "body")
    readonly_fields = ("created_at", "updated_at")


@admin.register(UserNotificationState)
class UserNotificationStateAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "notification", "read_at", "updated_at")
    list_filter = ("read_at", "updated_at")
    search_fields = ("user__username", "user__email", "notification__title")
    readonly_fields = ("created_at", "updated_at")


@admin.register(PushDeviceToken)
class PushDeviceTokenAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "platform", "is_active", "last_seen_at", "updated_at")
    list_filter = ("platform", "is_active", "updated_at")
    search_fields = ("user__username", "user__email", "token")
    readonly_fields = ("last_seen_at", "created_at", "updated_at")

from django.contrib import admin
from django.contrib import messages
from django.utils import timezone

from apps.notifications.models import (
    BroadcastNotification,
    PushDeviceToken,
    UserNotificationState,
)
from apps.notifications.push_service import send_topic_notification


@admin.register(BroadcastNotification)
class BroadcastNotificationAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "is_active",
        "show_in_app",
        "send_tray_push",
        "tray_push_topic",
        "tray_push_sent_at",
        "created_at",
        "updated_at",
    )
    list_filter = ("is_active", "show_in_app", "send_tray_push", "tray_push_topic", "created_at")
    search_fields = ("title", "body", "tray_push_topic")
    readonly_fields = ("tray_push_sent_at", "tray_push_last_error", "created_at", "updated_at")
    actions = ("send_selected_tray_push",)

    @admin.action(description="Send tray push now for selected notifications")
    def send_selected_tray_push(self, request, queryset):
        success_count = 0
        failed_count = 0
        for obj in queryset:
            ok, result = send_topic_notification(
                title=obj.title,
                body=obj.body,
                topic=obj.tray_push_topic,
                data={"notification_id": str(obj.id)},
            )
            if ok:
                obj.tray_push_sent_at = timezone.now()
                obj.tray_push_last_error = ""
                success_count += 1
            else:
                obj.tray_push_last_error = result
                failed_count += 1
            obj.save(update_fields=["tray_push_sent_at", "tray_push_last_error", "updated_at"])

        if success_count:
            self.message_user(
                request,
                f"Tray push sent for {success_count} notification(s).",
                level=messages.SUCCESS,
            )
        if failed_count:
            self.message_user(
                request,
                f"Tray push failed for {failed_count} notification(s). Check tray_push_last_error.",
                level=messages.ERROR,
            )

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        if not obj.is_active or not obj.send_tray_push:
            return
        ok, result = send_topic_notification(
            title=obj.title,
            body=obj.body,
            topic=obj.tray_push_topic,
            data={"notification_id": str(obj.id)},
        )
        if ok:
            obj.tray_push_sent_at = timezone.now()
            obj.tray_push_last_error = ""
            self.message_user(request, "Tray push sent successfully.", level=messages.SUCCESS)
        else:
            obj.tray_push_last_error = result
            self.message_user(
                request,
                f"Tray push failed: {result}",
                level=messages.ERROR,
            )
        obj.save(update_fields=["tray_push_sent_at", "tray_push_last_error", "updated_at"])


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

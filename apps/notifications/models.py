from django.conf import settings
from django.db import models
from django.utils import timezone

class BroadcastNotification(models.Model):
    title = models.CharField(max_length=140)
    body = models.TextField()
    is_active = models.BooleanField(default=True)
    show_in_app = models.BooleanField(default=True)
    send_tray_push = models.BooleanField(default=True)
    tray_push_topic = models.CharField(max_length=120, default="all_users")
    tray_push_sent_at = models.DateTimeField(null=True, blank=True)
    tray_push_last_error = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at", "-id")

    def __str__(self) -> str:
        return f"Notification({self.title})"


class UserNotificationState(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notification_states",
    )
    notification = models.ForeignKey(
        BroadcastNotification,
        on_delete=models.CASCADE,
        related_name="user_states",
    )
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "notification")
        ordering = ("-updated_at", "-id")

    def mark_read(self) -> None:
        if self.read_at is None:
            self.read_at = timezone.now()
            self.save(update_fields=["read_at", "updated_at"])


class PushDeviceToken(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="push_device_tokens",
    )
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=20, default="android")
    is_active = models.BooleanField(default=True)
    last_seen_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at", "-id")

    def __str__(self) -> str:
        return f"PushDeviceToken(user_id={self.user_id}, platform={self.platform})"

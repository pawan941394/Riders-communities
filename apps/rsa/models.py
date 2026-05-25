from django.conf import settings
from django.db import models


class RSATicket(models.Model):
    class Status(models.TextChoices):
        NEW = "new", "New"
        ASSIGNED = "assigned", "Assigned"
        IN_PROGRESS = "in_progress", "In progress"
        RESOLVED = "resolved", "Resolved"
        CANCELLED = "cancelled", "Cancelled"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="rsa_tickets",
    )
    vehicle = models.ForeignKey(
        "vehicle.Vehicle",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rsa_tickets",
    )
    phone_number = models.CharField(max_length=20, blank=True, default="")
    alternate_phone_number = models.CharField(max_length=20, blank=True, default="")
    region = models.CharField(max_length=80)
    issue = models.CharField(max_length=80)
    description = models.TextField(blank=True, default="")
    gps_latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    gps_longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    status = models.CharField(max_length=24, choices=Status.choices, default=Status.NEW)
    assigned_to_name = models.CharField(max_length=120, blank=True, default="")
    admin_notes = models.TextField(blank=True, default="")
    payment_link = models.URLField(max_length=500, null=True, blank=True, default=None)
    payment_status = models.CharField(max_length=40, null=True, blank=True, default=None)
    technician_name = models.CharField(max_length=120, null=True, blank=True, default=None)
    technician_location = models.CharField(max_length=200, null=True, blank=True, default=None)
    technician_phone_number = models.CharField(max_length=20, null=True, blank=True, default=None)
    resolved_at = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["status", "-created_at"]),
            models.Index(fields=["region"]),
            models.Index(fields=["issue"]),
        ]

    def __str__(self) -> str:
        return f"RSA #{self.id} - {self.user_id} - {self.status}"


class RSATicketHistory(models.Model):
    class Status(models.TextChoices):
        CREATED = "created", "Created"
        STATUS_CHANGED = "status_changed", "Status changed"
        NOTE_ADDED = "note_added", "Note added"
        ASSIGNED = "assigned", "Assigned"
        RESOLVED = "resolved", "Resolved"
        CANCELLED = "cancelled", "Cancelled"

    ticket = models.ForeignKey(
        RSATicket,
        on_delete=models.CASCADE,
        related_name="history",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rsa_history_entries",
    )
    status = models.CharField(max_length=32, choices=Status.choices)
    from_status = models.CharField(max_length=24, blank=True, default="")
    to_status = models.CharField(max_length=24, blank=True, default="")
    note = models.TextField(blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["ticket", "-created_at"]),
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["status"], name="rsa_hist_status_idx"),
        ]

    def __str__(self) -> str:
        return f"RSA history #{self.id} - ticket {self.ticket_id} - {self.status}"

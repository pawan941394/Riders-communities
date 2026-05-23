from django.conf import settings
from django.db import models


class Vehicle(models.Model):
    class VehicleType(models.TextChoices):
        EV_SCOOTER = "ev_scooter", "EV scooter"
        EV_BIKE = "ev_bike", "EV bike"
        BIKE = "bike", "Petrol"
        SCOOTER = "scooter", "Scooter"
        OTHER = "other", "Other"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="vehicle",
    )
    vehicle_type = models.CharField(
        max_length=32,
        choices=VehicleType.choices,
        default=VehicleType.EV_SCOOTER,
    )
    company_name = models.CharField(max_length=120, blank=True, default="")
    model_name = models.CharField(max_length=120, blank=True, default="")
    registration_number = models.CharField(max_length=40, blank=True, default="")
    chassis_number = models.CharField(max_length=80, blank=True, default="")
    battery_number = models.CharField(max_length=80, blank=True, default="")
    color = models.CharField(max_length=60, blank=True, default="")
    purchase_year = models.PositiveSmallIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at",)
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["registration_number"]),
            models.Index(fields=["chassis_number"]),
        ]

    def __str__(self) -> str:
        label = self.registration_number or self.chassis_number or f"user_id={self.user_id}"
        return f"Vehicle({label})"

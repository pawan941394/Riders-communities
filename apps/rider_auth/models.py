from django.contrib.auth import get_user_model
from django.core.validators import RegexValidator
from django.db import models

User = get_user_model()


class RiderProfile(models.Model):
    """Auth profile data collected from rider signup/onboarding."""

    phone_validator = RegexValidator(
        regex=r"^\+?[0-9]{10,15}$",
        message="Phone number must be 10-15 digits (optional leading +).",
    )

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="rider_profile",
    )
    phone_number = models.CharField(
        max_length=16,
        unique=True,
        validators=[phone_validator],
        help_text="Required at signup.",
    )
    profile_photo = models.ImageField(
        upload_to="rider_profiles/",
        blank=True,
        null=True,
        help_text="Required by frontend signup flow; enforced at API/serializer layer.",
    )
    rider_id = models.CharField(max_length=64, blank=True)
    rider_company = models.CharField(max_length=80, blank=True)
    city = models.CharField(max_length=80, blank=True)
    bio = models.TextField(blank=True, default="")
    preferred_language = models.CharField(max_length=20, default="en")
    is_phone_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.user.email or self.user.username} ({self.phone_number})"

from django.conf import settings
from django.db import models


class UserLanguage(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="language_pref",
    )
    language_code = models.CharField(
        max_length=12,
        default="en",
        help_text="App language code like en, hi, mr, bn, ta etc.",
    )
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-updated_at", "-id")
        verbose_name = "User language"
        verbose_name_plural = "User languages"

    def __str__(self) -> str:
        return f"UserLanguage(user_id={self.user_id}, code={self.language_code})"

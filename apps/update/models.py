from django.db import models


class AppVersionConfig(models.Model):
    DEFAULT_KEY = "default"
    DEFAULT_VERSION = "1.0.0"

    key = models.CharField(max_length=32, unique=True, default=DEFAULT_KEY, editable=False)
    version_name = models.CharField(
        max_length=40,
        default=DEFAULT_VERSION,
        help_text="Latest mandatory app version name/code (example: 1.0.3).",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "App Update Version"
        verbose_name_plural = "App Update Version"

    def __str__(self) -> str:
        return f"AppVersionConfig(version={self.version_name})"

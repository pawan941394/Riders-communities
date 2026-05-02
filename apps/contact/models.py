from django.conf import settings
from django.db import models


class InquiryIssue(models.Model):
    """Admin-managed issue types: drives Help tiles, EV hub tiles, and allowed contact slugs."""

    slug = models.SlugField(
        max_length=32,
        unique=True,
        help_text="Sent as inquiry_kind in API (lowercase, no spaces).",
    )
    title = models.CharField(max_length=120)
    subtitle = models.CharField(max_length=200, blank=True)
    detail_description = models.TextField(
        blank=True,
        help_text="Shown on the message form banner when this issue is opened from Help/EV.",
    )
    icon_key = models.CharField(
        max_length=64,
        blank=True,
        help_text="Flutter icon key, e.g. account_balance_wallet, support_agent.",
    )
    list_label = models.CharField(
        max_length=160,
        blank=True,
        help_text="Label in Contact form dropdown; if empty, title is used.",
    )
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    show_in_help = models.BooleanField(
        default=False,
        help_text="Show as a tile under Help & Support (below Contact us).",
    )
    show_in_ev_hub = models.BooleanField(
        default=False,
        help_text="Show as a quick action on the EV Support Hub screen.",
    )

    class Meta:
        ordering = ["sort_order", "title"]

    def __str__(self) -> str:
        return f"{self.title} ({self.slug})"


class ContactSubmission(models.Model):
    """Inbound contact form — inquiry type (slug), who it’s from, and message."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="contact_submissions",
        help_text="Filled when the app sends a valid Bearer token.",
    )
    inquiry_kind = models.CharField(max_length=32, db_index=True)
    full_name = models.CharField(max_length=160)
    email = models.EmailField()
    phone = models.CharField(max_length=20, blank=True)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        issue = InquiryIssue.objects.filter(slug=self.inquiry_kind).first()
        label = issue.title if issue else self.inquiry_kind
        who = self.full_name or self.email
        return f"{label} — {who}"

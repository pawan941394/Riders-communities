from django.conf import settings
from django.db import models


def _empty_doc_list() -> list:
    return []


class BuyEvPlan(models.Model):
    """Partner-led purchase listing — EMI/down ₹ amounts are not stored (rates & commission vary)."""

    slug = models.SlugField(max_length=80, unique=True, db_index=True)
    company_name = models.CharField(max_length=160)
    tagline = models.CharField(max_length=280)
    ex_showroom_from = models.DecimalField(max_digits=12, decimal_places=2)
    documents_required = models.JSONField(default=_empty_doc_list, blank=True)
    accent_a_hex = models.CharField(max_length=9, help_text='e.g. #0D9488')
    accent_b_hex = models.CharField(max_length=9, help_text='e.g. #14B8A6')
    partner_image = models.ImageField(
        upload_to="ev/buy/",
        blank=True,
        help_text="Card / detail hero image (served from this server; no external hosting).",
    )
    emi_available = models.BooleanField(default=True)
    down_payment_options_available = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "company_name", "slug"]

    def __str__(self) -> str:
        return f"{self.company_name} ({self.slug})"


class RentEvPlan(models.Model):
    """Rental partner listing — amounts indicative; confirm with partner."""

    slug = models.SlugField(max_length=80, unique=True, db_index=True)
    company_name = models.CharField(max_length=160)
    tagline = models.CharField(max_length=280)
    security_deposit = models.DecimalField(max_digits=12, decimal_places=2)
    weekly_rent = models.DecimalField(max_digits=12, decimal_places=2)
    daily_rent = models.DecimalField(max_digits=12, decimal_places=2)
    documents_required = models.JSONField(default=_empty_doc_list, blank=True)
    accent_a_hex = models.CharField(max_length=9, help_text='e.g. #2563EB')
    accent_b_hex = models.CharField(max_length=9)
    partner_image = models.ImageField(
        upload_to="ev/rent/",
        blank=True,
        help_text="Card / detail hero image (served from this server; no external hosting).",
    )
    featured = models.BooleanField(default=False)
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["sort_order", "company_name", "slug"]

    def __str__(self) -> str:
        return f"{self.company_name} ({self.slug})"


class EvPlanInterest(models.Model):
    """Rider interest — **buy** → [BuyEvPlan], **rent** → [RentEvPlan]."""

    class Channel(models.TextChoices):
        BUY = "buy", "Buy EV"
        RENT = "rent", "Rent EV"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="ev_plan_interests",
    )
    channel = models.CharField(max_length=8, choices=Channel.choices, db_index=True)
    buy_plan = models.ForeignKey(
        BuyEvPlan,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="interests",
        help_text="Buy EV catalog row.",
    )
    rent_plan = models.ForeignKey(
        RentEvPlan,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="interests",
        help_text="Rent EV catalog row.",
    )
    # Legacy / migration aid — prefer FKs; should be null once linked.
    plan_slug = models.SlugField(max_length=80, blank=True, null=True)
    partner_label = models.CharField(
        max_length=160,
        blank=True,
        help_text="Snapshot for admin list.",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "buy_plan"],
                condition=models.Q(channel="buy", buy_plan__isnull=False),
                name="unique_ev_interest_user_buy_plan",
            ),
            models.UniqueConstraint(
                fields=["user", "rent_plan"],
                condition=models.Q(channel="rent", rent_plan__isnull=False),
                name="unique_ev_interest_user_rent_plan",
            ),
        ]

    def __str__(self) -> str:
        if self.buy_plan_id is not None:
            return f"{self.user_id} buy → {self.buy_plan.slug}"
        if self.rent_plan_id is not None:
            return f"{self.user_id} rent → {self.rent_plan.slug}"
        return f"{self.user_id} {self.channel} {self.plan_slug or '?'}"


class EvLocation(models.Model):
    source_name = models.CharField(max_length=120, default="kml")
    source_url = models.CharField(max_length=500)
    external_id = models.CharField(max_length=64)

    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    geometry_type = models.CharField(max_length=30, default="Point")
    raw_coordinates = models.TextField(blank=True)
    raw_extended_data = models.JSONField(default=dict, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name", "-updated_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["source_url", "external_id"],
                name="unique_ev_location_per_source",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.latitude}, {self.longitude})"

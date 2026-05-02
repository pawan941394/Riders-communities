# Generated manually for InquiryIssue + unbounded inquiry_kind on ContactSubmission.

from django.db import migrations, models


def seed_inquiry_issues(apps, schema_editor):
    InquiryIssue = apps.get_model("contact", "InquiryIssue")
    rows = [
        dict(
            slug="payout",
            title="Payout Issue",
            subtitle="Missing earnings",
            detail_description="Share missing payout details and we will verify quickly.",
            icon_key="account_balance_wallet",
            list_label="",
            sort_order=10,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="safety",
            title="Safety Help",
            subtitle="Route concerns",
            detail_description="Report unsafe locations and request immediate support.",
            icon_key="health_and_safety",
            list_label="",
            sort_order=20,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="account_block",
            title="Account Block",
            subtitle="Unblock support",
            detail_description="Submit account block issue with rider details for resolution.",
            icon_key="lock_open",
            list_label="",
            sort_order=30,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="order",
            title="Order Support",
            subtitle="Delivery disputes",
            detail_description="Raise order-level support for wrong or cancelled assignments.",
            icon_key="local_shipping",
            list_label="",
            sort_order=40,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="bug",
            title="App Bug",
            subtitle="Technical issue",
            detail_description="Share app bugs and screenshots so our team can fix quickly.",
            icon_key="bug_report",
            list_label="",
            sort_order=50,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="general",
            title="General Help",
            subtitle="Talk to support",
            detail_description="Tell us your issue and our support team will contact you.",
            icon_key="support_agent",
            list_label="General enquiry",
            sort_order=60,
            is_active=True,
            show_in_help=True,
            show_in_ev_hub=False,
        ),
        dict(
            slug="callback",
            title="Book Callback",
            subtitle="Talk to team",
            detail_description="Request a call from EV support team at your preferred time.",
            icon_key="support_agent",
            list_label="",
            sort_order=5,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=True,
        ),
        dict(
            slug="buy_ev",
            title="Buy EV / finance",
            subtitle="",
            detail_description="",
            icon_key="electric_bike",
            list_label="",
            sort_order=100,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
        dict(
            slug="rent_ev",
            title="Rent EV",
            subtitle="",
            detail_description="",
            icon_key="electric_scooter",
            list_label="",
            sort_order=110,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
        dict(
            slug="charging",
            title="Charging & locations",
            subtitle="",
            detail_description="",
            icon_key="ev_station",
            list_label="",
            sort_order=120,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
        dict(
            slug="account",
            title="Account & login",
            subtitle="",
            detail_description="",
            icon_key="person",
            list_label="",
            sort_order=130,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
        dict(
            slug="feedback",
            title="Feedback",
            subtitle="",
            detail_description="",
            icon_key="feedback",
            list_label="",
            sort_order=140,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
        dict(
            slug="other",
            title="Other",
            subtitle="",
            detail_description="",
            icon_key="help_outline",
            list_label="",
            sort_order=999,
            is_active=True,
            show_in_help=False,
            show_in_ev_hub=False,
        ),
    ]
    for r in rows:
        InquiryIssue.objects.update_or_create(slug=r["slug"], defaults=r)


def unseed_inquiry_issues(apps, schema_editor):
    InquiryIssue = apps.get_model("contact", "InquiryIssue")
    InquiryIssue.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("contact", "0002_add_callback_inquiry_kind"),
    ]

    operations = [
        migrations.CreateModel(
            name="InquiryIssue",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("slug", models.SlugField(help_text="Sent as inquiry_kind in API (lowercase, no spaces).", max_length=32, unique=True)),
                ("title", models.CharField(max_length=120)),
                ("subtitle", models.CharField(blank=True, max_length=200)),
                ("detail_description", models.TextField(blank=True, help_text="Shown on the message form banner when this issue is opened from Help/EV.")),
                ("icon_key", models.CharField(blank=True, help_text="Flutter icon key, e.g. account_balance_wallet, support_agent.", max_length=64)),
                ("list_label", models.CharField(blank=True, help_text="Label in Contact form dropdown; if empty, title is used.", max_length=160)),
                ("sort_order", models.PositiveIntegerField(default=0)),
                ("is_active", models.BooleanField(default=True)),
                ("show_in_help", models.BooleanField(default=False, help_text="Show as a tile under Help & Support (below Contact us).")),
                ("show_in_ev_hub", models.BooleanField(default=False, help_text="Show as a quick action on the EV Support Hub screen.")),
            ],
            options={
                "ordering": ["sort_order", "title"],
            },
        ),
        migrations.RunPython(seed_inquiry_issues, unseed_inquiry_issues),
        migrations.AlterField(
            model_name="contactsubmission",
            name="inquiry_kind",
            field=models.CharField(db_index=True, max_length=32),
        ),
    ]

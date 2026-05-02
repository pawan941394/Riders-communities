# Replaces URL image links with uploaded files under MEDIA_ROOT.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("ev", "0006_rent_ev_plan_and_interest_fk"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="buyevplan",
            name="image_url",
        ),
        migrations.RemoveField(
            model_name="rentevplan",
            name="image_url",
        ),
        migrations.AddField(
            model_name="buyevplan",
            name="partner_image",
            field=models.ImageField(
                blank=True,
                help_text="Card / detail hero image (served from this server; no external hosting).",
                upload_to="ev/buy/",
            ),
        ),
        migrations.AddField(
            model_name="rentevplan",
            name="partner_image",
            field=models.ImageField(
                blank=True,
                help_text="Card / detail hero image (served from this server; no external hosting).",
                upload_to="ev/rent/",
            ),
        ),
    ]

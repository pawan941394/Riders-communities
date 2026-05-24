from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rsa", "0003_rename_history_event_to_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="rsaticket",
            name="payment_link",
            field=models.URLField(blank=True, default=None, max_length=500, null=True),
        ),
        migrations.AddField(
            model_name="rsaticket",
            name="payment_status",
            field=models.CharField(blank=True, default=None, max_length=40, null=True),
        ),
    ]


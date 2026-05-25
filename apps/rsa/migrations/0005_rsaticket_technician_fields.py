from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rsa", "0004_rsaticket_payment_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="rsaticket",
            name="technician_name",
            field=models.CharField(blank=True, default=None, max_length=120, null=True),
        ),
        migrations.AddField(
            model_name="rsaticket",
            name="technician_location",
            field=models.CharField(blank=True, default=None, max_length=200, null=True),
        ),
        migrations.AddField(
            model_name="rsaticket",
            name="technician_phone_number",
            field=models.CharField(blank=True, default=None, max_length=20, null=True),
        ),
    ]


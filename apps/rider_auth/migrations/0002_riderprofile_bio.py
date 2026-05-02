# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rider_auth", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="riderprofile",
            name="bio",
            field=models.TextField(blank=True, default=""),
        ),
    ]

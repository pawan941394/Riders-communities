# Generated manually to preserve existing RSA history values while renaming event to status.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("rsa", "0002_rsatickethistory"),
    ]

    operations = [
        migrations.RemoveIndex(
            model_name="rsatickethistory",
            name="rsa_rsatick_event_3ab4df_idx",
        ),
        migrations.RenameField(
            model_name="rsatickethistory",
            old_name="event",
            new_name="status",
        ),
        migrations.AddIndex(
            model_name="rsatickethistory",
            index=models.Index(fields=["status"], name="rsa_hist_status_idx"),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("notifications", "0003_broadcastnotification_tray_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="broadcastnotification",
            name="show_in_app",
            field=models.BooleanField(default=True),
        ),
    ]

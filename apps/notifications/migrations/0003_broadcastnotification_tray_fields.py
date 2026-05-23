from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("notifications", "0002_pushdevicetoken"),
    ]

    operations = [
        migrations.AddField(
            model_name="broadcastnotification",
            name="send_tray_push",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="broadcastnotification",
            name="tray_push_last_error",
            field=models.TextField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="broadcastnotification",
            name="tray_push_sent_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="broadcastnotification",
            name="tray_push_topic",
            field=models.CharField(default="all_users", max_length=120),
        ),
    ]

from django.conf import settings
from django.db import migrations


def backfill_user_language(apps, schema_editor):
    User = apps.get_model(*settings.AUTH_USER_MODEL.split("."))
    UserLanguage = apps.get_model("language", "UserLanguage")

    existing_user_ids = set(UserLanguage.objects.values_list("user_id", flat=True))
    to_create = []
    for user_id in User.objects.values_list("id", flat=True):
        if user_id in existing_user_ids:
            continue
        to_create.append(UserLanguage(user_id=user_id, language_code="en"))
    if to_create:
        UserLanguage.objects.bulk_create(to_create, batch_size=1000)

    UserLanguage.objects.filter(language_code__isnull=True).update(language_code="en")
    UserLanguage.objects.filter(language_code="").update(language_code="en")


class Migration(migrations.Migration):
    dependencies = [
        ("language", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(backfill_user_language, migrations.RunPython.noop),
    ]

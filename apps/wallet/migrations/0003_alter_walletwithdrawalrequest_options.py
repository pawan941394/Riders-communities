from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("wallet", "0002_walletwithdrawalrequest"),
    ]

    operations = [
        migrations.AlterModelOptions(
            name="walletwithdrawalrequest",
            options={
                "ordering": ("-created_at", "-id"),
                "verbose_name": "Wallet withdrawal request",
                "verbose_name_plural": "Wallet withdrawal requests",
            },
        ),
    ]

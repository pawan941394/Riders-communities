# Generated manually — demo catalog aligned with app BuyEvPlan demo.

from decimal import Decimal

from django.db import migrations


def seed_buy_ev(apps, schema_editor):
    BuyEvPlan = apps.get_model("ev", "BuyEvPlan")
    rows = [
        {
            "slug": "ampere_nexus",
            "company_name": "Ampere (Greaves)",
            "tagline": "Nexus & city scooters — dealer finance",
            "ex_showroom_from": Decimal("112000.00"),
            "documents_required": [
                "Aadhar & PAN",
                "Income proof (bank / ITR)",
                "Address proof",
                "Passport-size photo",
            ],
            "accent_a_hex": "#0D9488",
            "accent_b_hex": "#14B8A6",
            "image_url": "https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 10,
        },
        {
            "slug": "ather_rizta",
            "company_name": "Ather Energy",
            "tagline": "Rizta & 450X — NCR showrooms",
            "ex_showroom_from": Decimal("104000.00"),
            "documents_required": [
                "Aadhar & PAN",
                "Salary slip / ITR",
                "Bank statement (3 months)",
                "Reference contact",
            ],
            "accent_a_hex": "#DC2626",
            "accent_b_hex": "#F97316",
            "image_url": "https://images.unsplash.com/photo-1593948757756-f27449918983?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 20,
        },
        {
            "slug": "hero_vida",
            "company_name": "Hero Vida",
            "tagline": "Family EV scooters · finance partners",
            "ex_showroom_from": Decimal("98900.00"),
            "documents_required": ["Aadhar Card", "PAN Card", "Income proof", "Selfie"],
            "accent_a_hex": "#2563EB",
            "accent_b_hex": "#38BDF8",
            "image_url": "https://images.unsplash.com/photo-1568772585407-9361d9cd87d5?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 30,
        },
        {
            "slug": "ola_s1",
            "company_name": "Ola Electric",
            "tagline": "S1 range — online + experience centres",
            "ex_showroom_from": Decimal("89999.00"),
            "documents_required": ["Aadhar & PAN", "Bank statement", "Employment proof"],
            "accent_a_hex": "#15803D",
            "accent_b_hex": "#22C55E",
            "image_url": "https://images.unsplash.com/photo-1571068316344-75bc76f77890?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 40,
        },
        {
            "slug": "tvs_iqube",
            "company_name": "TVS iQube",
            "tagline": "Trusted network · exchange bonus options",
            "ex_showroom_from": Decimal("121000.00"),
            "documents_required": [
                "Aadhar & PAN",
                "ITR / Form 16",
                "Cheque for booking",
                "Insurance nominee details",
            ],
            "accent_a_hex": "#C2410C",
            "accent_b_hex": "#EA580C",
            "image_url": "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 50,
        },
        {
            "slug": "bajaj_chetak",
            "company_name": "Bajaj Chetak",
            "tagline": "Classic brand · finance schemes via partners",
            "ex_showroom_from": Decimal("115000.00"),
            "documents_required": [
                "Aadhar Card",
                "PAN Card",
                "Salary account proof",
                "Photo",
            ],
            "accent_a_hex": "#7C3AED",
            "accent_b_hex": "#A78BFA",
            "image_url": "https://images.unsplash.com/photo-1449426468159-96d0d0526911?auto=format&fit=crop&w=1280&q=85",
            "sort_order": 60,
        },
    ]
    common = {
        "emi_available": True,
        "down_payment_options_available": True,
        "is_active": True,
    }
    for row in rows:
        slug = row.pop("slug")
        defaults = {**row, **common}
        BuyEvPlan.objects.update_or_create(slug=slug, defaults=defaults)


def unseed_buy_ev(apps, schema_editor):
    BuyEvPlan = apps.get_model("ev", "BuyEvPlan")
    BuyEvPlan.objects.filter(
        slug__in=[
            "ampere_nexus",
            "ather_rizta",
            "hero_vida",
            "ola_s1",
            "tvs_iqube",
            "bajaj_chetak",
        ]
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("ev", "0002_buy_ev_plan"),
    ]

    operations = [
        migrations.RunPython(seed_buy_ev, unseed_buy_ev),
    ]

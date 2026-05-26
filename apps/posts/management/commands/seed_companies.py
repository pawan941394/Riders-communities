"""Seed configurable companies with brand categories and colors."""

from django.core.management.base import BaseCommand
from django.db import transaction
from apps.posts.models import PostCompanyOption


class Command(BaseCommand):
    help = "Seed standard rider delivery and taxi companies with categories and brand colors."

    def handle(self, *args, **options):
        # List of companies with brand specifications
        companies_data = [
            # Food Delivery
            {
                "label": "Zomato",
                "category": "Food Delivery",
                "brand_color": "#CB202D",
                "sort_order": 1,
            },
            {
                "label": "Swiggy",
                "category": "Food Delivery",
                "brand_color": "#FC8019",
                "sort_order": 2,
            },
            {
                "label": "Popeyes",
                "category": "Food Delivery",
                "brand_color": "#F15A24",
                "sort_order": 3,
            },
            {
                "label": "FNP",
                "category": "Food Delivery",
                "brand_color": "#4A773C",
                "sort_order": 4,
            },
            # Bike Taxi
            {
                "label": "Ola",
                "category": "Bike Taxi",
                "brand_color": "#000000",
                "sort_order": 5,
            },
            {
                "label": "Uber",
                "category": "Bike Taxi",
                "brand_color": "#000000",
                "sort_order": 6,
            },
            {
                "label": "Rapido",
                "category": "Bike Taxi",
                "brand_color": "#FFE000",
                "sort_order": 7,
            },
            # Ecommerce
            {
                "label": "Zepto",
                "category": "Ecommerce",
                "brand_color": "#5E2B97",
                "sort_order": 8,
            },
            {
                "label": "Blinkit",
                "category": "Ecommerce",
                "brand_color": "#F7EC13",
                "sort_order": 9,
            },
            # Parcel
            {
                "label": "Porter",
                "category": "Parcel",
                "brand_color": "#421EAE",
                "sort_order": 10,
            },
            # Other Services
            {
                "label": "Other",
                "category": "Other Services",
                "brand_color": "#0B1F3A",
                "sort_order": 11,
            },
        ]

        self.stdout.write("Seeding configurable companies...")

        with transaction.atomic():
            # First, clean up existing initial minimal choices so they get re-seeded with brand details
            labels_to_seed = [c["label"] for c in companies_data]
            PostCompanyOption.objects.filter(label__in=labels_to_seed).delete()

            for item in companies_data:
                company, created = PostCompanyOption.objects.update_or_create(
                    label=item["label"],
                    defaults={
                        "category": item["category"],
                        "brand_color": item["brand_color"],
                        "sort_order": item["sort_order"],
                        "is_active": True,
                    },
                )
                status = "Created" if created else "Updated"
                self.stdout.write(
                    f"  - {company.label} | Category: {company.category} | Color: {company.brand_color} ({status})"
                )

        self.stdout.write(self.style.SUCCESS("Successfully seeded all configurable company options!"))

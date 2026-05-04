from django.conf import settings
from django.shortcuts import render


def privacy_policy(request):
    """Public privacy policy page for app stores (no auth)."""
    return render(
        request,
        "legal/privacy.html",
        {
            "site_name": getattr(settings, "LEGAL_SITE_NAME", "Ridermanch"),
            "operator_name": getattr(settings, "LEGAL_OPERATOR_NAME", "Bharat AI Connect"),
            "public_origin": getattr(settings, "PUBLIC_BASE_URL", "").rstrip("/"),
            "support_email": getattr(settings, "SUPPORT_EMAIL", ""),
            "last_updated": getattr(settings, "LEGAL_POLICY_UPDATED", "May 2026"),
        },
    )

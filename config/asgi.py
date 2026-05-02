"""
ASGI entry: FastAPI at /api/v1, Django everywhere else (admin, auth, future routes).

Run (from backend/):
  uv run uvicorn config.asgi:application --reload --host 127.0.0.1 --port 8000
"""

import os

from django.core.asgi import get_asgi_application
from django.conf import settings
from django.contrib.staticfiles.handlers import ASGIStaticFilesHandler
from starlette.applications import Starlette
from starlette.responses import RedirectResponse
from starlette.routing import Mount, Route

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

django_asgi_app = get_asgi_application()
if settings.DEBUG:
    django_asgi_app = ASGIStaticFilesHandler(django_asgi_app)

from apps.api.main import app as fastapi_app  # noqa: E402


async def _redirect_to_fastapi_docs(_request):
    return RedirectResponse(url="/api/v1/docs", status_code=307)


async def _redirect_to_fastapi_redoc(_request):
    return RedirectResponse(url="/api/v1/redoc", status_code=307)


async def _redirect_to_fastapi_openapi(_request):
    return RedirectResponse(url="/api/v1/openapi.json", status_code=307)


application = Starlette(
    routes=[
        Route("/docs", endpoint=_redirect_to_fastapi_docs),
        Route("/redoc", endpoint=_redirect_to_fastapi_redoc),
        Route("/openapi.json", endpoint=_redirect_to_fastapi_openapi),
        Mount("/api/v1", app=fastapi_app),
        Mount("/", app=django_asgi_app),
    ],
)

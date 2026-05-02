"""FastAPI app mounted at /api/v1 (see config.asgi)."""

import os
import secrets
from pathlib import Path

from dotenv import load_dotenv
from fastapi import APIRouter, Depends, FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from apps.contact.api import router as contact_router
from apps.ev.api import router as ev_router
from apps.posts.api import router as posts_router
from apps.rider_auth.api import router as rider_auth_router

load_dotenv(Path(__file__).resolve().parents[2] / ".env")
API_ACCESS_KEY = os.getenv("FASTAPI_X_API_KEY", "dev-rider-api-key")

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "fastapi"}


def verify_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")) -> None:
    if not x_api_key or not secrets.compare_digest(x_api_key, API_ACCESS_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-Key.",
        )


def create_app() -> FastAPI:
    app = FastAPI(title="Rider Community API", version="0.1.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(router, dependencies=[Depends(verify_api_key)])
    app.include_router(rider_auth_router, dependencies=[Depends(verify_api_key)])
    app.include_router(ev_router, dependencies=[Depends(verify_api_key)])
    app.include_router(posts_router, dependencies=[Depends(verify_api_key)])
    app.include_router(contact_router, dependencies=[Depends(verify_api_key)])
    return app


app = create_app()

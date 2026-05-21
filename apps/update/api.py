from fastapi import APIRouter
from pydantic import BaseModel, Field

from apps.update.models import AppVersionConfig

router = APIRouter(prefix="/update", tags=["App Update"])


class AppVersionCheckIn(BaseModel):
    version_name: str = Field(min_length=1, max_length=40)


class AppVersionCheckOut(BaseModel):
    up_to_date: bool
    force_update: bool
    required_version: str
    current_version: str
    message: str


@router.post("/check", response_model=AppVersionCheckOut)
def check_app_version(payload: AppVersionCheckIn) -> AppVersionCheckOut:
    cfg, _ = AppVersionConfig.objects.get_or_create(
        key=AppVersionConfig.DEFAULT_KEY,
        defaults={"version_name": AppVersionConfig.DEFAULT_VERSION},
    )
    required = (cfg.version_name or "").strip()
    current = (payload.version_name or "").strip()
    is_same = current.lower() == required.lower()

    if is_same:
        return AppVersionCheckOut(
            up_to_date=True,
            force_update=False,
            required_version=required,
            current_version=current,
            message="App is up to date.",
        )

    return AppVersionCheckOut(
        up_to_date=False,
        force_update=True,
        required_version=required,
        current_version=current,
        message="Please update the app first to continue.",
    )

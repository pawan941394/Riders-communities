from django.contrib.auth import get_user_model
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from apps.language.models import UserLanguage
from apps.rider_auth.api import current_user_dep

router = APIRouter(prefix="/language", tags=["Language"])
User = get_user_model()


class UserLanguageOut(BaseModel):
    language_code: str


class UserLanguageSetIn(BaseModel):
    language_code: str = Field(min_length=2, max_length=12)


class UserLanguageSetOut(BaseModel):
    success: bool
    message: str
    language_code: str


@router.get("/me", response_model=UserLanguageOut)
def get_my_language(user: User = Depends(current_user_dep)) -> UserLanguageOut:
    row, _ = UserLanguage.objects.get_or_create(
        user=user,
        defaults={"language_code": "en"},
    )
    return UserLanguageOut(language_code=(row.language_code or "en").strip().lower() or "en")


@router.post("/set", response_model=UserLanguageSetOut)
def set_my_language(
    payload: UserLanguageSetIn,
    user: User = Depends(current_user_dep),
) -> UserLanguageSetOut:
    code = (payload.language_code or "").strip().lower()
    row, _ = UserLanguage.objects.get_or_create(
        user=user,
        defaults={"language_code": code or "en"},
    )
    if code:
        row.language_code = code
        row.save(update_fields=["language_code", "updated_at"])
    final_code = (row.language_code or "en").strip().lower() or "en"
    return UserLanguageSetOut(
        success=True,
        message="Language updated.",
        language_code=final_code,
    )

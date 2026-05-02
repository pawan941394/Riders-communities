import os
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.db import transaction
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    UploadFile,
    status,
)

from apps.posts.models import Post, PostComment, PostReaction

from apps.rider_auth.models import RiderProfile

router = APIRouter(prefix="/auth", tags=["Rider Auth"])
User = get_user_model()
JWT_SECRET = os.getenv("FASTAPI_JWT_SECRET", "dev-rider-jwt-secret")
JWT_ALGORITHM = "HS256"
JWT_EXP_MINUTES = int(os.getenv("FASTAPI_JWT_EXP_MINUTES", "10080"))


def current_user_dep(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
        )
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )
    sub = payload.get("sub")
    if sub is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload.")
    try:
        user_id = int(sub)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject.")
    user = User.objects.filter(pk=user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")
    return user


def optional_current_user_dep(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> User | None:
    """Same JWT as [current_user_dep], but returns None if missing/invalid (no 401)."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        return None
    sub = payload.get("sub")
    if sub is None:
        return None
    try:
        user_id = int(sub)
    except (TypeError, ValueError):
        return None
    return User.objects.filter(pk=user_id).first()


# Backwards-compatible alias for internal use.
_current_user_dep = current_user_dep


class LoginRequest(BaseModel):
    phone_number: str = Field(min_length=10, max_length=16)
    password: str = Field(min_length=3, max_length=128)


class UserProfileData(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    full_name: str
    username: str
    email: str
    phone_number: str
    profile_photo_url: str | None = None
    rider_company: str | None = None
    rider_id: str | None = None
    city: str | None = None
    bio: str = ""
    preferred_language: str | None = None


class ProfileStatsOut(BaseModel):
    posts_count: int
    helpful_count: int
    replies_count: int


class ProfileMeResponse(BaseModel):
    profile: UserProfileData
    stats: ProfileStatsOut


class AuthResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    message: str
    user_id: int
    access_token: str
    token_type: str = "bearer"
    profile: UserProfileData





def _build_unique_username(full_name: str) -> str:
    first_name = (full_name.strip().split(" ")[0] if full_name.strip() else "rider").lower()
    first_name = "".join(ch for ch in first_name if ch.isalnum()) or "rider"
    idx = 1
    while True:
        candidate = f"{first_name}_{idx:03d}"
        if not User.objects.filter(username=candidate).exists():
            return candidate
        idx += 1


def _create_access_token(user_id: int, phone_number: str) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "phone_number": phone_number,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=JWT_EXP_MINUTES)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _build_profile_response(user, profile, request: Request) -> UserProfileData:
    photo_url = None
    if profile.profile_photo:
        photo_url = f"{str(request.base_url).rstrip('/')}{profile.profile_photo.url}"
    return UserProfileData(
        full_name=f"{user.first_name} {user.last_name}".strip() or user.username,
        username=user.username,
        email=user.email,
        phone_number=profile.phone_number,
        profile_photo_url=photo_url,
        rider_company=profile.rider_company or None,
        rider_id=profile.rider_id or None,
        city=profile.city or None,
        bio=(profile.bio or "").strip(),
        preferred_language=profile.preferred_language or None,
    )


def _profile_stats(user: User) -> ProfileStatsOut:
    posts_count = Post.objects.filter(author=user, is_deleted=False).count()
    replies_count = PostComment.objects.filter(author=user, is_deleted=False).count()
    helpful_count = PostReaction.objects.filter(
        post__author=user,
        post__is_deleted=False,
        kind=PostReaction.Kind.LIKE,
    ).count()
    return ProfileStatsOut(
        posts_count=posts_count,
        helpful_count=helpful_count,
        replies_count=replies_count,
    )


@router.get("/me", response_model=ProfileMeResponse)
def get_me(request: Request, user: User = Depends(current_user_dep)) -> ProfileMeResponse:
    profile = RiderProfile.objects.filter(user=user).select_related("user").first()
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rider profile not found.")
    return ProfileMeResponse(
        profile=_build_profile_response(user, profile, request),
        stats=_profile_stats(user),
    )


@router.patch("/profile", response_model=UserProfileData)
def patch_profile(
    request: Request,
    user: User = Depends(current_user_dep),
    bio: str | None = Form(default=None),
    profile_photo: UploadFile | None = File(default=None),
) -> UserProfileData:
    profile = RiderProfile.objects.filter(user=user).select_related("user").first()
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rider profile not found.")

    changed = False
    if bio is not None:
        profile.bio = bio.strip()
        changed = True

    photo_updated = False
    if profile_photo is not None and profile_photo.filename:
        photo_ext = os.path.splitext(profile_photo.filename)[1].lower() or ".jpg"
        photo_name = f"rider_{user.id}_{uuid.uuid4().hex[:10]}{photo_ext}"
        photo_bytes = profile_photo.file.read()
        profile.profile_photo.save(photo_name, ContentFile(photo_bytes), save=True)
        changed = True
        photo_updated = True

    if not changed:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update.")

    if not photo_updated:
        profile.save()

    return _build_profile_response(user, profile, request)


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def signup(
    request: Request,
    full_name: str = Form(...),
    email: EmailStr = Form(...),
    password: str = Form(..., min_length=3, max_length=128),
    phone_number: str = Form(..., min_length=10, max_length=16),
    profile_photo: UploadFile = File(...),
    rider_id: str | None = Form(default=None),
    rider_company: str | None = Form(default=None),
    city: str | None = Form(default=None),
    preferred_language: str = Form(default="en"),
) -> AuthResponse:
    full_name = full_name.strip()
    if not full_name:
        raise HTTPException(status_code=400, detail="Full name is required.")
    if not profile_photo.filename:
        raise HTTPException(status_code=400, detail="Profile photo is required.")

    email = str(email).lower().strip()
    phone = phone_number.strip()

    if User.objects.filter(email=email).exists():
        raise HTTPException(status_code=400, detail="Email already registered.")
    if RiderProfile.objects.filter(phone_number=phone).exists():
        raise HTTPException(status_code=400, detail="Phone number already registered.")

    with transaction.atomic():
        name_parts = full_name.split()
        first_name = name_parts[0]
        last_name = " ".join(name_parts[1:]) if len(name_parts) > 1 else ""

        user = User.objects.create_user(
            username=_build_unique_username(full_name),
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        profile = RiderProfile.objects.create(
            user=user,
            phone_number=phone,
            rider_id=(rider_id or "").strip(),
            rider_company=(rider_company or "").strip(),
            city=(city or "").strip(),
            preferred_language=(preferred_language or "en").strip().lower(),
        )

        photo_ext = os.path.splitext(profile_photo.filename)[1].lower() or ".jpg"
        photo_name = f"rider_{user.id}_{uuid.uuid4().hex[:10]}{photo_ext}"
        photo_bytes = profile_photo.file.read()
        profile.profile_photo.save(photo_name, ContentFile(photo_bytes), save=True)

    return AuthResponse(
        message="Signup successful.",
        user_id=user.id,
        access_token=_create_access_token(user.id, profile.phone_number),
        profile=_build_profile_response(user, profile, request),
    )


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, request: Request) -> AuthResponse:
    phone = payload.phone_number.strip()
    profile = RiderProfile.objects.filter(phone_number=phone).select_related("user").first()
    if profile is None:
        raise HTTPException(status_code=401, detail="Invalid phone number or password.")
    user = profile.user
    if not user.check_password(payload.password):
        raise HTTPException(status_code=401, detail="Invalid phone number or password.")

    return AuthResponse(
        message="Login successful.",
        user_id=user.id,
        access_token=_create_access_token(user.id, profile.phone_number),
        profile=_build_profile_response(user, profile, request),
    )


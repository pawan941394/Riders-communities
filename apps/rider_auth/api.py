import os
import uuid
from datetime import UTC, datetime, timedelta
import jwt
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.db import transaction
from django.db.models import Q
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

from apps.language.models import UserLanguage
from apps.referral.models import ReferralCode
from apps.referral.services import (
    ReferralApplyError,
    apply_referral_code_for_user,
    generate_unique_referral_code,
)
from apps.rider_auth.models import RiderProfile

router = APIRouter(prefix="/auth", tags=["Rider Auth"])
User = get_user_model()
JWT_ALGORITHM = "HS256"


def _jwt_secret() -> str:
    return os.getenv("FASTAPI_JWT_SECRET", "dev-rider-jwt-secret")


def _jwt_exp_minutes() -> int:
    try:
        minutes = int(os.getenv("FASTAPI_JWT_EXP_MINUTES", "43200"))
    except (TypeError, ValueError):
        minutes = 43200
    return max(minutes, 1)


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
        payload = jwt.decode(token, _jwt_secret(), algorithms=[JWT_ALGORITHM])
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
        payload = jwt.decode(token, _jwt_secret(), algorithms=[JWT_ALGORITHM])
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


class OtpPrecheckRequest(BaseModel):
    phone_number: str = Field(min_length=10, max_length=20)


class OtpPrecheckResponse(BaseModel):
    message: str
    phone_number: str
    user_exists: bool
    signup_required: bool


class OtpCompleteLoginRequest(BaseModel):
    phone_number: str = Field(min_length=10, max_length=20)
    otp_verified: bool = True
    verification_ref: str | None = Field(default=None, max_length=128)


class OtpCompleteLoginResponse(BaseModel):
    message: str
    user_exists: bool
    signup_required: bool
    user_id: int | None = None
    access_token: str | None = None
    token_type: str = "bearer"
    profile: "UserProfileData | None" = None


class OtpRegisterRequest(BaseModel):
    phone_number: str = Field(min_length=10, max_length=20)
    full_name: str = Field(min_length=1, max_length=120)
    email: EmailStr | None = None
    rider_id: str | None = Field(default=None, max_length=64)
    rider_company: str | None = Field(default=None, max_length=80)
    city: str | None = Field(default=None, max_length=80)
    preferred_language: str = Field(default="en", max_length=20)
    referral_code: str | None = Field(default=None, max_length=32)
    otp_verified: bool = True
    verification_ref: str | None = Field(default=None, max_length=128)


class OtpConfigResponse(BaseModel):
    enabled: bool
    widget_id: str
    auth_token: str


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
    language_code: str | None = None
    referral_code: str | None = None


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
        "exp": int((now + timedelta(minutes=_jwt_exp_minutes())).timestamp()),
    }
    return jwt.encode(payload, _jwt_secret(), algorithm=JWT_ALGORITHM)


def _digits_only(value: str) -> str:
    return "".join(ch for ch in value if ch.isdigit())


def _canonical_phone(phone_number: str) -> str:
    digits = _digits_only(phone_number.strip())
    if digits.startswith("91") and len(digits) == 12:
        return digits[2:]
    return digits


def _phone_candidates(phone_number: str) -> list[str]:
    raw = phone_number.strip()
    digits = _digits_only(raw)
    out: list[str] = []
    for candidate in (raw, digits):
        if candidate and candidate not in out:
            out.append(candidate)
    if digits.startswith("91") and len(digits) == 12:
        local = digits[2:]
        for candidate in (local, f"+{digits}"):
            if candidate and candidate not in out:
                out.append(candidate)
    elif len(digits) == 10:
        with_cc = f"91{digits}"
        for candidate in (with_cc, f"+{with_cc}"):
            if candidate and candidate not in out:
                out.append(candidate)
    return out


def _find_profile_by_phone(phone_number: str) -> RiderProfile | None:
    candidates = _phone_candidates(phone_number)
    if not candidates:
        return None
    query = Q()
    for candidate in candidates:
        query |= Q(phone_number=candidate)
    return RiderProfile.objects.filter(query).select_related("user").first()


def _build_profile_response(user, profile, request: Request) -> UserProfileData:
    photo_url = None
    if profile.profile_photo:
        photo_url = f"{str(request.base_url).rstrip('/')}{profile.profile_photo.url}"
    referral_row, _ = ReferralCode.objects.get_or_create(
        user=user,
        defaults={"code": generate_unique_referral_code()},
    )
    language_row = UserLanguage.objects.filter(user=user).first()
    language_code = "en"
    if language_row is not None:
        language_code = (language_row.language_code or "").strip().lower() or "en"
    else:
        language_code = ((profile.preferred_language or "").strip().lower() or "en")

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
        language_code=language_code,
        referral_code=referral_row.code,
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
    rider_id: str | None = Form(default=None),
    rider_company: str | None = Form(default=None),
    city: str | None = Form(default=None),
    profile_photo: UploadFile | None = File(default=None),
) -> UserProfileData:
    profile = RiderProfile.objects.filter(user=user).select_related("user").first()
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rider profile not found.")

    received_field = False
    changed = False
    if bio is not None:
        received_field = True
        next_bio = bio.strip()
        if profile.bio != next_bio:
            profile.bio = next_bio
            changed = True

    if rider_id is not None:
        received_field = True
        next_rider_id = rider_id.strip()
        if not next_rider_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rider ID is required.",
            )
        if (profile.rider_id or "").strip() != next_rider_id:
            profile.rider_id = next_rider_id
            changed = True

    if rider_company is not None:
        received_field = True
        next_company = rider_company.strip()
        if not next_company:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rider company is required.",
            )
        if (profile.rider_company or "").strip() != next_company:
            profile.rider_company = next_company
            changed = True

    if city is not None:
        received_field = True
        next_city = city.strip()
        if not next_city:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="City is required.",
            )
        if next_city and (profile.city or "").strip() != next_city:
            profile.city = next_city
            changed = True

    photo_updated = False
    if profile_photo is not None and profile_photo.filename:
        received_field = True
        photo_ext = os.path.splitext(profile_photo.filename)[1].lower() or ".jpg"
        photo_name = f"rider_{user.id}_{uuid.uuid4().hex[:10]}{photo_ext}"
        photo_bytes = profile_photo.file.read()
        profile.profile_photo.save(photo_name, ContentFile(photo_bytes), save=True)
        changed = True
        photo_updated = True

    if not received_field:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update.")

    if not photo_updated:
        if changed:
            profile.save()

    return _build_profile_response(user, profile, request)


@router.get("/otp/config", response_model=OtpConfigResponse)
def otp_config() -> OtpConfigResponse:
    widget_id = os.getenv("SENDOTP_WIDGET_ID", "").strip()
    auth_token = os.getenv("SENDOTP_AUTH_TOKEN", "").strip()
    enabled = bool(widget_id and auth_token)
    return OtpConfigResponse(
        enabled=enabled,
        widget_id=widget_id,
        auth_token=auth_token,
    )


@router.post("/otp/precheck", response_model=OtpPrecheckResponse)
def otp_precheck(payload: OtpPrecheckRequest) -> OtpPrecheckResponse:
    normalized_phone = _canonical_phone(payload.phone_number)
    if len(normalized_phone) < 10:
        raise HTTPException(status_code=400, detail="Valid phone number is required.")
    profile = _find_profile_by_phone(normalized_phone)
    user_exists = profile is not None
    return OtpPrecheckResponse(
        message="OTP precheck completed.",
        phone_number=normalized_phone,
        user_exists=user_exists,
        signup_required=not user_exists,
    )


@router.post("/otp/complete-login", response_model=OtpCompleteLoginResponse)
def otp_complete_login(
    payload: OtpCompleteLoginRequest,
    request: Request,
) -> OtpCompleteLoginResponse:
    if not payload.otp_verified:
        raise HTTPException(status_code=400, detail="OTP must be verified before login.")
    normalized_phone = _canonical_phone(payload.phone_number)
    if len(normalized_phone) < 10:
        raise HTTPException(status_code=400, detail="Valid phone number is required.")

    profile = _find_profile_by_phone(normalized_phone)
    if profile is None:
        return OtpCompleteLoginResponse(
            message="User not found. Please complete signup.",
            user_exists=False,
            signup_required=True,
        )

    user = profile.user
    return OtpCompleteLoginResponse(
        message="OTP login successful.",
        user_exists=True,
        signup_required=False,
        user_id=user.id,
        access_token=_create_access_token(user.id, profile.phone_number),
        profile=_build_profile_response(user, profile, request),
    )


@router.post("/otp/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def otp_register(payload: OtpRegisterRequest, request: Request) -> AuthResponse:
    if not payload.otp_verified:
        raise HTTPException(status_code=400, detail="OTP must be verified before signup.")

    full_name = payload.full_name.strip()
    if not full_name:
        raise HTTPException(status_code=400, detail="Full name is required.")

    phone = _canonical_phone(payload.phone_number)
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="Valid phone number is required.")
    if _find_profile_by_phone(phone) is not None:
        raise HTTPException(status_code=400, detail="Phone number already registered.")

    email = (str(payload.email).strip().lower() if payload.email else "")
    if email and User.objects.filter(email=email).exists():
        raise HTTPException(status_code=400, detail="Email already registered.")

    referral_code_clean = (payload.referral_code or "").strip().upper()
    preferred_language = "en"

    with transaction.atomic():
        name_parts = full_name.split()
        first_name = name_parts[0]
        last_name = " ".join(name_parts[1:]) if len(name_parts) > 1 else ""

        user = User.objects.create_user(
            username=_build_unique_username(full_name),
            email=email,
            password=None,
            first_name=first_name,
            last_name=last_name,
        )
        user.set_unusable_password()
        user.save(update_fields=["password"])

        profile = RiderProfile.objects.create(
            user=user,
            phone_number=phone,
            rider_id=(payload.rider_id or "").strip(),
            rider_company=(payload.rider_company or "").strip(),
            city=(payload.city or "").strip(),
            preferred_language="en",
            is_phone_verified=True,
        )
        UserLanguage.objects.get_or_create(
            user=user,
            defaults={"language_code": "en"},
        )

        if referral_code_clean:
            try:
                apply_referral_code_for_user(
                    referred_user=user,
                    referral_code=referral_code_clean,
                    channel="signup",
                )
            except ReferralApplyError as exc:
                raise HTTPException(status_code=400, detail=str(exc))

    return AuthResponse(
        message="Signup successful.",
        user_id=user.id,
        access_token=_create_access_token(user.id, profile.phone_number),
        profile=_build_profile_response(user, profile, request),
    )


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
    referral_code: str | None = Form(default=None),
) -> AuthResponse:
    full_name = full_name.strip()
    if not full_name:
        raise HTTPException(status_code=400, detail="Full name is required.")
    if not profile_photo.filename:
        raise HTTPException(status_code=400, detail="Profile photo is required.")

    email = str(email).lower().strip()
    phone = phone_number.strip()
    referral_code_clean = (referral_code or "").strip().upper()

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
            preferred_language="en",
        )
        UserLanguage.objects.get_or_create(
            user=user,
            defaults={"language_code": "en"},
        )

        photo_ext = os.path.splitext(profile_photo.filename)[1].lower() or ".jpg"
        photo_name = f"rider_{user.id}_{uuid.uuid4().hex[:10]}{photo_ext}"
        photo_bytes = profile_photo.file.read()
        profile.profile_photo.save(photo_name, ContentFile(photo_bytes), save=True)

        if referral_code_clean:
            try:
                apply_referral_code_for_user(
                    referred_user=user,
                    referral_code=referral_code_clean,
                    channel="signup",
                )
            except ReferralApplyError as exc:
                raise HTTPException(status_code=400, detail=str(exc))

    return AuthResponse(
        message="Signup successful.",
        user_id=user.id,
        access_token=_create_access_token(user.id, profile.phone_number),
        profile=_build_profile_response(user, profile, request),
    )


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, request: Request) -> AuthResponse:
    phone = payload.phone_number.strip()
    profile = _find_profile_by_phone(phone)
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

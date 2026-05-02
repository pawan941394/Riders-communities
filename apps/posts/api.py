import os
import uuid
from datetime import datetime
from typing import Literal

import jwt
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.db.models import Count, Prefetch, Q
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, Request, UploadFile, status
from pydantic import BaseModel, ConfigDict

from apps.posts.models import Post, PostCityOption, PostComment, PostCompanyOption, PostIssueTypeOption, PostReaction
from apps.rider_auth.models import RiderProfile

router = APIRouter(tags=["Posts"])
User = get_user_model()
JWT_SECRET = os.getenv("FASTAPI_JWT_SECRET", "dev-rider-jwt-secret")
JWT_ALGORITHM = "HS256"


def _current_user_dep(
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


def _optional_current_user(
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> User | None:
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


class PostCreatedOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    body: str
    city: str
    company: str
    is_anonymous: bool
    image_url: str | None = None
    created_at: datetime


class PostMetaItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str


class PostMetaResponse(BaseModel):
    cities: list[PostMetaItem]
    companies: list[PostMetaItem]
    issue_types: list[PostMetaItem]


class PostReactionBody(BaseModel):
    kind: Literal["like", "dislike", "none"]


class PostReactionOut(BaseModel):
    likes_count: int
    dislikes_count: int
    viewer_reaction: str | None


class CommentCreateIn(BaseModel):
    body: str
    parent_id: int | None = None


def _comment_author_profile(user: User) -> tuple[str, str, str]:
    """Returns (display line, company label, city label)."""
    city = ""
    company = ""
    try:
        rp = user.rider_profile
        city = (rp.city or "").strip()
        company = (rp.rider_company or "").strip()
    except RiderProfile.DoesNotExist:
        pass
    name = f"{user.first_name} {user.last_name}".strip()
    if name:
        display = f"{name}, {city}" if city else name
    else:
        display = user.username
    return display, company, city


def _comment_avatar_for_api(request: Request, user: User) -> tuple[str | None, str]:
    initial = _display_name_initial(user)
    try:
        profile = user.rider_profile
    except RiderProfile.DoesNotExist:
        return None, initial
    if profile.profile_photo:
        return _absolute_media_url(request, profile.profile_photo.url), initial
    return None, initial


def _serialize_comment_leaf(request: Request, c: PostComment) -> dict:
    display, company, city = _comment_author_profile(c.author)
    av_url, initial = _comment_avatar_for_api(request, c.author)
    return {
        "id": c.id,
        "author_display": display,
        "author_avatar_url": av_url,
        "author_initial": initial,
        "company": company,
        "city": city,
        "body": c.body,
        "created_at": c.created_at.isoformat(),
        "replies": [],
    }


def _serialize_comment_tree(request: Request, c: PostComment, replies: list[PostComment]) -> dict:
    base = _serialize_comment_leaf(request, c)
    base["replies"] = [_serialize_comment_leaf(request, r) for r in replies]
    return base


def _active_city_labels() -> set[str]:
    return set(
        PostCityOption.objects.filter(is_active=True).values_list("label", flat=True),
    )


def _active_company_labels() -> set[str]:
    return set(
        PostCompanyOption.objects.filter(is_active=True).values_list("label", flat=True),
    )


def _normalize_search_query(raw: str) -> str:
    """Trim and strip leading # characters so tag-style searches match stored [Tag] bodies."""
    t = (raw or "").strip()
    while t.startswith("#"):
        t = t[1:].strip()
    return t


def _strip_issue_prefix(body: str) -> tuple[str, list[str]]:
    raw = (body or "").strip()
    if not raw.startswith("["):
        return raw, []
    close = raw.find("]")
    if close == -1 or close > 48:
        return raw, []
    tag = raw[1:close].strip()
    rest = raw[close + 1 :].lstrip()
    return rest, ([tag] if tag else [])


def _author_display(post: Post) -> str:
    if post.is_anonymous:
        return "Anonymous Rider"
    u = post.author
    name = f"{u.first_name} {u.last_name}".strip()
    if name:
        return f"{name}, {post.city}"
    return u.username


def _absolute_media_url(request: Request, relative: str) -> str:
    root = str(request.base_url).rstrip("/").removesuffix("/api/v1")
    return f"{root}{relative}"


def _first_letter_from_label(label: str) -> str | None:
    for ch in label.strip():
        if ch.isalnum():
            return ch.upper()
    return None


def _display_name_initial(user: User) -> str:
    """Avatar letter: first name, else last name, else username."""
    for part in ((user.first_name or "").strip(), (user.last_name or "").strip()):
        if not part:
            continue
        letter = _first_letter_from_label(part)
        if letter:
            return letter
    uname = (user.username or "").strip()
    if uname:
        letter = _first_letter_from_label(uname)
        if letter:
            return letter
    return "?"


def _author_avatar_for_feed(request: Request, post: Post) -> tuple[str | None, str]:
    """Public feed: no avatar URL for anonymous posts. Letter from legal/display name when possible."""
    if post.is_anonymous:
        return None, "?"
    user = post.author
    initial = _display_name_initial(user)

    avatar_url = None
    try:
        profile = user.rider_profile
    except RiderProfile.DoesNotExist:
        profile = None
    if profile and profile.profile_photo:
        avatar_url = _absolute_media_url(request, profile.profile_photo.url)
    return avatar_url, initial


@router.get("/posts/meta", response_model=PostMetaResponse)
def post_meta() -> PostMetaResponse:
    cities = [
        PostMetaItem(id=row.id, label=row.label)
        for row in PostCityOption.objects.filter(is_active=True).order_by("sort_order", "label")
    ]
    companies = [
        PostMetaItem(id=row.id, label=row.label)
        for row in PostCompanyOption.objects.filter(is_active=True).order_by("sort_order", "label")
    ]
    issue_types = [
        PostMetaItem(id=row.id, label=row.label)
        for row in PostIssueTypeOption.objects.filter(is_active=True).order_by("sort_order", "label")
    ]
    return PostMetaResponse(cities=cities, companies=companies, issue_types=issue_types)


def _posts_feed_base_queryset():
    return (
        Post.objects.filter(is_deleted=False)
        .select_related("author", "author__rider_profile")
        .annotate(
            likes_count=Count(
                "reactions",
                filter=Q(reactions__kind=PostReaction.Kind.LIKE),
                distinct=True,
            ),
            dislikes_count=Count(
                "reactions",
                filter=Q(reactions__kind=PostReaction.Kind.DISLIKE),
                distinct=True,
            ),
            comments_count=Count("comments", filter=Q(comments__is_deleted=False)),
        )
    )


def _serialize_post_for_api(request: Request, post: Post, viewer_reaction: str | None) -> dict:
    display_body, tags = _strip_issue_prefix(post.body)
    image_url = None
    if post.image:
        image_url = _absolute_media_url(request, post.image.url)
    author_avatar_url, author_initial = _author_avatar_for_feed(request, post)
    return {
        "id": post.id,
        "author_display": _author_display(post),
        "author_avatar_url": author_avatar_url,
        "author_initial": author_initial,
        "body": display_body,
        "body_full": post.body,
        "city": post.city,
        "company": post.company,
        "is_anonymous": post.is_anonymous,
        "tags": tags,
        "image_url": image_url,
        "comments_count": getattr(post, "comments_count", 0),
        "likes_count": getattr(post, "likes_count", 0),
        "dislikes_count": getattr(post, "dislikes_count", 0),
        "viewer_reaction": viewer_reaction,
        "created_at": post.created_at.isoformat(),
    }


@router.get("/posts/me")
def list_my_posts(
    request: Request,
    user: User = Depends(_current_user_dep),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
) -> dict:
    """Current user's posts (non-deleted), newest first. Same item shape as GET /posts."""
    qs = _posts_feed_base_queryset().filter(author=user).order_by("-created_at", "-id")
    total = qs.count()
    page = list(qs[offset : offset + limit])

    viewer_by_post: dict[int, str] = {}
    if page:
        pids = [p.id for p in page]
        viewer_by_post = {
            row.post_id: row.kind
            for row in PostReaction.objects.filter(user=user, post_id__in=pids)
        }

    items = []
    for post in page:
        vr = viewer_by_post.get(post.id)
        items.append(_serialize_post_for_api(request, post, vr))

    return {"total": total, "limit": limit, "offset": offset, "items": items}


@router.get("/posts/{post_id}")
def get_post_detail(
    post_id: int,
    request: Request,
    viewer: User | None = Depends(_optional_current_user),
) -> dict:
    """Single post (same fields as each item in GET /posts)."""
    post = _posts_feed_base_queryset().filter(pk=post_id).first()
    if post is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found.")
    vr = None
    if viewer:
        row = PostReaction.objects.filter(post_id=post_id, user=viewer).first()
        if row:
            vr = row.kind
    return _serialize_post_for_api(request, post, vr)


@router.get("/posts/{post_id}/comments")
def list_post_comments(post_id: int, request: Request) -> dict:
    """Top-level comments with nested replies (one level). Newest threads first."""
    if not Post.objects.filter(pk=post_id, is_deleted=False).exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found.")

    roots = (
        PostComment.objects.filter(post_id=post_id, parent__isnull=True, is_deleted=False)
        .select_related("author", "author__rider_profile")
        .prefetch_related(
            Prefetch(
                "replies",
                queryset=PostComment.objects.filter(is_deleted=False)
                .select_related("author", "author__rider_profile")
                .order_by("created_at"),
            ),
        )
        .order_by("-created_at")
    )
    items = [_serialize_comment_tree(request, c, list(c.replies.all())) for c in roots]
    return {"items": items}


@router.post("/posts/{post_id}/comments")
def create_post_comment(
    post_id: int,
    payload: CommentCreateIn,
    request: Request,
    user: User = Depends(_current_user_dep),
) -> dict:
    post = Post.objects.filter(pk=post_id, is_deleted=False).first()
    if post is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found.")

    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Comment cannot be empty.")
    if len(body) > 2000:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Comment is too long (max 2000 characters).")

    parent: PostComment | None = None
    if payload.parent_id is not None:
        parent = PostComment.objects.filter(
            pk=payload.parent_id,
            post_id=post_id,
            is_deleted=False,
        ).first()
        if parent is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid parent comment.")
        if parent.parent_id is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You can only reply to a top-level comment.",
            )

    c = PostComment(post=post, author=user, parent=parent, body=body)
    c.save()
    c = PostComment.objects.select_related("author", "author__rider_profile").get(pk=c.pk)
    return _serialize_comment_leaf(request, c)


@router.get("/posts")
def list_posts(
    request: Request,
    viewer: User | None = Depends(_optional_current_user),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    city: str = "",
    company: str = "",
    search: str = "",
    issue_type: str = "",
) -> dict:
    """Paginated community feed (non-deleted posts). Same limit/offset style as EV locations."""
    qs = _posts_feed_base_queryset().order_by("-created_at", "-id")

    c = city.strip()
    if c and c.lower() != "all":
        qs = qs.filter(city__iexact=c)

    co = company.strip()
    if co and co.lower() not in ("all", "all companies"):
        qs = qs.filter(company__iexact=co)

    it = issue_type.strip()
    if it and it.lower() not in ("all", "all types"):
        qs = qs.filter(body__istartswith=f"[{it}]")

    term = _normalize_search_query(search)
    if term:
        bracket_prefix = f"[{term}]"
        qs = qs.filter(
            Q(body__icontains=term)
            | Q(city__icontains=term)
            | Q(company__icontains=term)
            | Q(body__istartswith=bracket_prefix),
        )

    total = qs.count()
    page = list(qs[offset : offset + limit])

    viewer_by_post: dict[int, str] = {}
    if viewer is not None and page:
        pids = [p.id for p in page]
        viewer_by_post = {
            row.post_id: row.kind
            for row in PostReaction.objects.filter(user=viewer, post_id__in=pids)
        }

    items = []
    for post in page:
        vr = viewer_by_post.get(post.id)
        items.append(_serialize_post_for_api(request, post, vr))

    return {"total": total, "limit": limit, "offset": offset, "items": items}


@router.post("/posts/{post_id}/reaction", response_model=PostReactionOut)
def set_post_reaction(
    post_id: int,
    payload: PostReactionBody,
    user: User = Depends(_current_user_dep),
) -> PostReactionOut:
    post = Post.objects.filter(pk=post_id, is_deleted=False).first()
    if post is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found.")

    if payload.kind == "none":
        PostReaction.objects.filter(post=post, user=user).delete()
    else:
        PostReaction.objects.update_or_create(
            post=post,
            user=user,
            defaults={"kind": payload.kind},
        )

    likes = PostReaction.objects.filter(post=post, kind=PostReaction.Kind.LIKE).count()
    dislikes = PostReaction.objects.filter(post=post, kind=PostReaction.Kind.DISLIKE).count()
    row = PostReaction.objects.filter(post=post, user=user).first()
    vr = row.kind if row else None
    return PostReactionOut(likes_count=likes, dislikes_count=dislikes, viewer_reaction=vr)


@router.post("/posts", response_model=PostCreatedOut, status_code=status.HTTP_201_CREATED)
def create_post(
    request: Request,
    user: User = Depends(_current_user_dep),
    body: str = Form(..., min_length=1),
    city: str = Form(..., max_length=80),
    company: str = Form(..., max_length=120),
    is_anonymous: bool = Form(False),
    image: UploadFile | None = File(None),
) -> PostCreatedOut:
    city = city.strip()
    company = company.strip()
    body = body.strip()
    if not body:
        raise HTTPException(status_code=400, detail="Body cannot be empty.")
    if not city:
        raise HTTPException(status_code=400, detail="City is required.")
    if not company:
        raise HTTPException(status_code=400, detail="Company is required.")

    allowed_cities = _active_city_labels()
    if not allowed_cities:
        raise HTTPException(status_code=503, detail="Post city options are not configured.")
    if city not in allowed_cities:
        raise HTTPException(status_code=400, detail="Invalid or inactive city.")

    allowed_companies = _active_company_labels()
    if not allowed_companies:
        raise HTTPException(status_code=503, detail="Post company options are not configured.")
    if company not in allowed_companies:
        raise HTTPException(status_code=400, detail="Invalid or inactive company.")

    post = Post(author=user, body=body, city=city, company=company, is_anonymous=is_anonymous)

    if image is not None and image.filename:
        ext = os.path.splitext(image.filename)[1].lower() or ".jpg"
        if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
            raise HTTPException(status_code=400, detail="Unsupported image type.")
        raw = image.file.read()
        if len(raw) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Image must be 5MB or smaller.")
        fname = f"post_{user.id}_{uuid.uuid4().hex[:12]}{ext}"
        post.image.save(fname, ContentFile(raw), save=False)

    post.save()

    image_url = None
    if post.image:
        root = str(request.base_url).rstrip("/").removesuffix("/api/v1")
        image_url = f"{root}{post.image.url}"

    return PostCreatedOut(
        id=post.id,
        body=post.body,
        city=post.city,
        company=post.company,
        is_anonymous=post.is_anonymous,
        image_url=image_url,
        created_at=post.created_at,
    )

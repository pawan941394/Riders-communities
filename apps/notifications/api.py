from django.contrib.auth import get_user_model
from django.db import transaction
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from apps.notifications.models import (
    BroadcastNotification,
    PushDeviceToken,
    UserNotification,
    UserNotificationState,
)
from apps.rider_auth.api import current_user_dep

router = APIRouter(prefix="/notifications", tags=["Notifications"])
User = get_user_model()


class NotificationItemOut(BaseModel):
    id: int
    source: str = "broadcast"
    title: str
    body: str
    created_at: str
    is_read: bool
    kind: str | None = None
    post_id: int | None = None


class NotificationInboxOut(BaseModel):
    items: list[NotificationItemOut]


class NotificationReadOut(BaseModel):
    success: bool
    message: str


class RegisterDeviceIn(BaseModel):
    token: str | None = None
    device_token: str | None = None
    fcm_token: str | None = None
    platform: str = Field(default="android", max_length=20)


class RegisterDeviceOut(BaseModel):
    success: bool
    message: str


@router.get("/inbox", response_model=NotificationInboxOut)
def inbox(
    limit: int = Query(default=20, ge=1, le=100),
    user: User = Depends(current_user_dep),
) -> NotificationInboxOut:
    broadcasts = list(
        BroadcastNotification.objects.filter(is_active=True, show_in_app=True)
        .order_by("-created_at", "-id")[:limit]
    )
    user_rows = list(
        UserNotification.objects.filter(user=user).order_by("-created_at", "-id")[:limit],
    )

    state_by_notification_id: dict[int, UserNotificationState] = {}
    if broadcasts:
        state_rows = UserNotificationState.objects.filter(
            user=user,
            notification_id__in=[n.id for n in broadcasts],
        ).select_related("notification")
        state_by_notification_id = {row.notification_id: row for row in state_rows}

    items: list[tuple] = []
    for n in broadcasts:
        state = state_by_notification_id.get(n.id)
        items.append(
            (
                n.created_at,
                NotificationItemOut(
                    id=n.id,
                    source="broadcast",
                    title=n.title,
                    body=n.body,
                    created_at=n.created_at.isoformat(),
                    is_read=bool(state and state.read_at),
                ),
            ),
        )
    for n in user_rows:
        items.append(
            (
                n.created_at,
                NotificationItemOut(
                    id=n.id,
                    source="user",
                    title=n.title,
                    body=n.body,
                    created_at=n.created_at.isoformat(),
                    is_read=bool(n.read_at),
                    kind=n.kind,
                    post_id=n.post_id,
                ),
            ),
        )

    items.sort(key=lambda pair: pair[0], reverse=True)
    return NotificationInboxOut(items=[row for _, row in items[:limit]])


@router.post("/{notification_id}/read", response_model=NotificationReadOut)
def mark_read(
    notification_id: int,
    source: str = Query(default="broadcast"),
    user: User = Depends(current_user_dep),
) -> NotificationReadOut:
    if source == "user":
        row = UserNotification.objects.filter(id=notification_id, user=user).first()
        if row is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found.",
            )
        row.mark_read()
        return NotificationReadOut(success=True, message="Notification marked as read.")

    notification = BroadcastNotification.objects.filter(
        id=notification_id,
        is_active=True,
        show_in_app=True,
    ).first()
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    with transaction.atomic():
        state, _ = UserNotificationState.objects.get_or_create(
            user=user,
            notification=notification,
        )
        state.mark_read()

    return NotificationReadOut(success=True, message="Notification marked as read.")


@router.post("/devices/register", response_model=RegisterDeviceOut)
def register_device_token(payload: RegisterDeviceIn, user: User = Depends(current_user_dep)) -> RegisterDeviceOut:
    token = (payload.token or payload.device_token or payload.fcm_token or "").strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Device token is required.",
        )

    platform = (payload.platform or "android").strip().lower()[:20]
    if not platform:
        platform = "android"

    PushDeviceToken.objects.update_or_create(
        token=token,
        defaults={
            "user": user,
            "platform": platform,
            "is_active": True,
        },
    )

    return RegisterDeviceOut(success=True, message="Device token saved.")

from django.contrib.auth import get_user_model
from django.db import transaction
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from apps.notifications.models import BroadcastNotification, UserNotificationState
from apps.rider_auth.api import current_user_dep

router = APIRouter(prefix="/notifications", tags=["Notifications"])
User = get_user_model()


class NotificationItemOut(BaseModel):
    id: int
    title: str
    body: str
    created_at: str
    is_read: bool


class NotificationInboxOut(BaseModel):
    items: list[NotificationItemOut]


class NotificationReadOut(BaseModel):
    success: bool
    message: str


@router.get("/inbox", response_model=NotificationInboxOut)
def inbox(
    limit: int = Query(default=20, ge=1, le=100),
    user: User = Depends(current_user_dep),
) -> NotificationInboxOut:
    notifications = list(BroadcastNotification.objects.filter(is_active=True).order_by("-created_at", "-id")[:limit])
    if not notifications:
        return NotificationInboxOut(items=[])

    notification_ids = [n.id for n in notifications]
    state_rows = UserNotificationState.objects.filter(
        user=user,
        notification_id__in=notification_ids,
    ).select_related("notification")
    state_by_notification_id = {row.notification_id: row for row in state_rows}

    items: list[NotificationItemOut] = []
    for n in notifications:
        state = state_by_notification_id.get(n.id)
        items.append(
            NotificationItemOut(
                id=n.id,
                title=n.title,
                body=n.body,
                created_at=n.created_at.isoformat(),
                is_read=bool(state and state.read_at),
            )
        )

    return NotificationInboxOut(items=items)


@router.post("/{notification_id}/read", response_model=NotificationReadOut)
def mark_read(notification_id: int, user: User = Depends(current_user_dep)) -> NotificationReadOut:
    notification = BroadcastNotification.objects.filter(id=notification_id, is_active=True).first()
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


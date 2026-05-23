from django.contrib.auth import get_user_model

from apps.notifications.models import PushDeviceToken, UserNotification
from apps.notifications.push_service import send_tokens_notification

User = get_user_model()


def create_user_notification(
    *,
    user: User,
    actor: User | None,
    kind: str,
    title: str,
    body: str,
    post_id: int | None = None,
    metadata: dict | None = None,
    send_tray_push: bool = True,
) -> UserNotification:
    row = UserNotification.objects.create(
        user=user,
        actor=actor,
        kind=kind,
        title=title.strip()[:140],
        body=body.strip(),
        post_id=post_id,
        metadata=metadata or {},
    )

    if send_tray_push:
        tokens = list(
            PushDeviceToken.objects.filter(user=user, is_active=True).values_list("token", flat=True),
        )
        send_tokens_notification(
            title=row.title,
            body=row.body or "You have a new update.",
            tokens=tokens,
            data={
                "type": "user_notification",
                "notification_id": str(row.id),
                "notification_source": "user",
                "post_id": str(post_id or ""),
                "kind": row.kind,
            },
        )

    return row

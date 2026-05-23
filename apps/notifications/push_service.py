import json
import os
from typing import Optional, Tuple

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception:  # pragma: no cover
    firebase_admin = None
    credentials = None
    messaging = None


_firebase_app = None


def _init_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    if firebase_admin is None or credentials is None:
        raise RuntimeError("firebase-admin package is not installed.")

    raw_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    json_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_FILE", "").strip()

    if raw_json:
        try:
            info = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            raise RuntimeError("Invalid FIREBASE_SERVICE_ACCOUNT_JSON.") from exc
        cred = credentials.Certificate(info)
        _firebase_app = firebase_admin.initialize_app(cred)
        return _firebase_app

    if json_path:
        if not os.path.exists(json_path):
            raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_FILE does not exist.")
        cred = credentials.Certificate(json_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        return _firebase_app

    raise RuntimeError(
        "Firebase credentials missing. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_FILE."
    )


def send_topic_notification(
    *,
    title: str,
    body: str,
    topic: str,
    data: Optional[dict[str, str]] = None,
) -> Tuple[bool, str]:
    try:
        _init_firebase_app()
        clean_topic = (topic or "all_users").strip().replace("/topics/", "")
        if not clean_topic:
            clean_topic = "all_users"
        message = messaging.Message(
            notification=messaging.Notification(
                title=title.strip()[:140],
                body=body.strip()[:1024],
            ),
            topic=clean_topic,
            data=data or {},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="ridewithgarv_general",
                    icon="ic_stat_ridewithgarv",
                    color="#FFC928",
                ),
            ),
        )
        message_id = messaging.send(message)
        return True, message_id
    except Exception as exc:  # pragma: no cover
        return False, str(exc)

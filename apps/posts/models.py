from django.conf import settings
from django.db import models


class PostCityOption(models.Model):
    """Configurable city labels for posts (admin-managed)."""

    label = models.CharField(max_length=80, unique=True)
    sort_order = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        ordering = ["sort_order", "label"]
        verbose_name = "post city option"
        verbose_name_plural = "post city options"

    def __str__(self) -> str:
        return self.label


class PostCompanyOption(models.Model):
    """Configurable company labels for posts (admin-managed)."""

    label = models.CharField(max_length=120, unique=True)
    sort_order = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        ordering = ["sort_order", "label"]
        verbose_name = "post company option"
        verbose_name_plural = "post company options"

    def __str__(self) -> str:
        return self.label


class PostIssueTypeOption(models.Model):
    """Configurable issue-type labels (stored inside post body as [Label])."""

    label = models.CharField(max_length=80, unique=True)
    sort_order = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        ordering = ["sort_order", "label"]
        verbose_name = "post issue type option"
        verbose_name_plural = "post issue type options"

    def __str__(self) -> str:
        return self.label


class Post(models.Model):
    """Rider community post: text + optional single image, city/company metadata."""

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="posts",
    )
    body = models.TextField(help_text="Post text content.")
    image = models.ImageField(
        upload_to="post_images/%Y/%m/",
        blank=True,
        null=True,
        help_text="At most one image per post (enforce in API).",
    )
    city = models.CharField(
        max_length=80,
        db_index=True,
        help_text="Mandatory launch metadata (NCR city etc.).",
    )
    company = models.CharField(
        max_length=120,
        db_index=True,
        help_text="Delivery company; use predefined label or 'Other'.",
    )
    is_anonymous = models.BooleanField(
        default=False,
        help_text="If true, hide author from riders in feed; admins still see author.",
    )
    is_deleted = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Soft-delete: hidden from riders, retained for admin.",
    )
    deleted_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["-created_at", "city"]),
            models.Index(fields=["is_deleted", "-created_at"]),
        ]

    def __str__(self) -> str:
        preview = (self.body[:50] + "…") if len(self.body) > 50 else self.body
        return f"Post {self.pk} by {self.author_id}: {preview}"


class PostComment(models.Model):
    """Threaded discussion on a post: top-level comments and one level of replies."""

    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="comments",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_comments",
    )
    parent = models.ForeignKey(
        "self",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="replies",
        help_text="Null = top-level comment; set to a top-level comment id for a reply.",
    )
    body = models.TextField()
    is_deleted = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["post", "parent", "-created_at"]),
            models.Index(fields=["post", "is_deleted", "-created_at"]),
        ]

    def __str__(self) -> str:
        return f"Comment {self.pk} on post {self.post_id}"


class PostReaction(models.Model):
    """One reaction per user per post: like XOR dislike."""

    class Kind(models.TextChoices):
        LIKE = "like", "Like"
        DISLIKE = "dislike", "Dislike"

    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name="reactions",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="post_reactions",
    )
    kind = models.CharField(max_length=10, choices=Kind.choices)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["post", "user"], name="posts_postreaction_post_user_uniq"),
        ]
        indexes = [
            models.Index(fields=["post", "kind"]),
        ]

    def __str__(self) -> str:
        return f"{self.kind} on {self.post_id} by {self.user_id}"

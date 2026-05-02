from django.contrib import admin

from apps.posts.models import Post, PostCityOption, PostComment, PostCompanyOption, PostIssueTypeOption, PostReaction


@admin.register(PostCityOption)
class PostCityOptionAdmin(admin.ModelAdmin):
    list_display = ("label", "sort_order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("label",)
    ordering = ("sort_order", "label")


@admin.register(PostCompanyOption)
class PostCompanyOptionAdmin(admin.ModelAdmin):
    list_display = ("label", "sort_order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("label",)
    ordering = ("sort_order", "label")


@admin.register(PostIssueTypeOption)
class PostIssueTypeOptionAdmin(admin.ModelAdmin):
    list_display = ("label", "sort_order", "is_active")
    list_filter = ("is_active",)
    search_fields = ("label",)
    ordering = ("sort_order", "label")


@admin.register(PostComment)
class PostCommentAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "author", "parent_id", "is_deleted", "created_at")
    list_filter = ("is_deleted",)
    raw_id_fields = ("post", "author", "parent")
    search_fields = ("body", "author__username")


@admin.register(PostReaction)
class PostReactionAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "user", "kind")
    list_filter = ("kind",)
    raw_id_fields = ("post", "user")
    search_fields = ("post__body", "user__username")


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("id", "author", "city", "company", "is_anonymous", "is_deleted", "created_at")
    list_filter = ("is_deleted", "is_anonymous", "city", "company")
    search_fields = ("body", "author__username", "author__email")
    readonly_fields = ("created_at", "updated_at", "deleted_at")
    raw_id_fields = ("author",)

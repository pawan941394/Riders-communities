import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import '../config/api_config.dart';

/// Relative time for comments (aligned with feed card timing).
String _formatCommentRelativeTime(String? iso) {
  if (iso == null || iso.isEmpty) {
    return '';
  }
  final DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) {
    return '';
  }
  final Duration diff = DateTime.now().difference(dt.toLocal());
  if (diff.isNegative) {
    return 'Just now';
  }
  if (diff.inSeconds < 50) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 8) {
    return '${diff.inDays}d ago';
  }
  final DateTime local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

class _CommentVm {
  const _CommentVm({
    required this.id,
    required this.authorDisplay,
    required this.company,
    required this.city,
    required this.body,
    this.avatarUrl,
    required this.initial,
    this.createdAtIso,
    required this.replies,
  });

  final int id;
  final String authorDisplay;
  final String company;
  final String city;
  final String body;
  final String? avatarUrl;
  final String initial;
  final String? createdAtIso;
  final List<_CommentVm> replies;

  static _CommentVm fromJson(Map<String, dynamic> m) {
    final List<dynamic> rawReplies = m['replies'] is List<dynamic>
        ? m['replies'] as List<dynamic>
        : const <dynamic>[];
    return _CommentVm(
      id: m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}') ?? 0,
      authorDisplay: '${m['author_display'] ?? 'Rider'}',
      company: '${m['company'] ?? ''}',
      city: '${m['city'] ?? ''}',
      body: '${m['body'] ?? ''}',
      avatarUrl: m['author_avatar_url'] is String
          ? m['author_avatar_url'] as String
          : null,
      initial: '${m['author_initial'] ?? '?'}',
      createdAtIso: m['created_at'] is String
          ? m['created_at'] as String
          : null,
      replies: rawReplies
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.apiBaseUrl,
    required this.author,
    required this.problem,
    required this.city,
    required this.company,
    required this.tags,
    required this.commentsCount,
    required this.isAnonymous,
    this.imageUrl,
    this.bodyFull,
    this.authorAvatarUrl,
    this.authorInitial = '?',
    required this.likesCount,
    required this.dislikesCount,
    this.viewerReaction,
  });

  final int postId;
  final String apiBaseUrl;
  final String author;

  /// Feed-style display body (prefix stripped).
  final String problem;
  final String? bodyFull;
  final String city;
  final String company;
  final List<String> tags;
  final int commentsCount;
  final bool isAnonymous;
  final String? imageUrl;
  final String? authorAvatarUrl;
  final String authorInitial;
  final int likesCount;
  final int dislikesCount;
  final String? viewerReaction;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const int _detailLongTextThreshold = 220;
  static const String _apiKey = ApiConfig.apiAccessKey;

  final TextEditingController _replyController = TextEditingController();
  final GoogleTranslator _commentTranslator = GoogleTranslator();

  late String _author;
  late String _displayBody;
  String? _bodyFull;
  late String _city;
  late String _company;
  late List<String> _tags;
  String? _imageUrl;
  late bool _anonymous;
  String? _avatarUrl;
  late String _avatarInitial;

  late int _likes;
  late int _dislikes;
  String? _viewer;
  bool _reactionBusy = false;
  String? _busySide;

  int _serverCommentsCount = 0;
  bool _loadingDetail = false;

  List<_CommentVm> _roots = <_CommentVm>[];
  bool _loadingComments = false;
  String? _commentsLoadError;
  bool _postingComment = false;

  final Map<int, bool> _commentTranslated = <int, bool>{};
  final Map<int, String?> _commentTranslatedText = <int, String?>{};
  final Map<int, bool> _commentTranslating = <int, bool>{};

  bool _mainTranslated = false;
  bool _mainTranslating = false;
  String? _mainTranslatedText;

  int get _replyHeaderCount => _serverCommentsCount;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    _serverCommentsCount = widget.commentsCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPostDetail();
      _fetchComments();
    });
  }

  void _syncFromWidget() {
    _author = widget.author;
    _displayBody = widget.problem;
    _bodyFull = widget.bodyFull;
    _city = widget.city;
    _company = widget.company;
    _tags = List<String>.from(widget.tags);
    _imageUrl = widget.imageUrl;
    _anonymous = widget.isAnonymous;
    _avatarUrl = widget.authorAvatarUrl;
    _avatarInitial = widget.authorInitial;
    _likes = widget.likesCount;
    _dislikes = widget.dislikesCount;
    _viewer = widget.viewerReaction;
  }

  int _parseInt(dynamic v, int fallback) {
    if (v is int) {
      return v;
    }
    return int.tryParse('$v') ?? fallback;
  }

  String _initialFromApi(dynamic v) {
    final String s = v is String ? v.trim() : '';
    return s.isNotEmpty ? s : _avatarInitial;
  }

  void _applyDetailJson(Map<String, dynamic> m) {
    _author = '${m['author_display'] ?? _author}';
    final String b = '${m['body'] ?? ''}'.trim();
    final String bf = '${m['body_full'] ?? m['body'] ?? ''}'.trim();
    if (b.isNotEmpty) {
      _displayBody = b;
    }
    _bodyFull = bf.isNotEmpty ? bf : _bodyFull;
    _city = '${m['city'] ?? _city}';
    _company = '${m['company'] ?? _company}';
    _anonymous = m['is_anonymous'] == true;
    final List<String> nextTags = <String>[];
    final dynamic t = m['tags'];
    if (t is List<dynamic>) {
      for (final dynamic x in t) {
        if (x is String && x.trim().isNotEmpty) {
          nextTags.add(x.trim());
        }
      }
    }
    _tags = nextTags.isNotEmpty ? nextTags : List<String>.from(widget.tags);
    final dynamic iu = m['image_url'];
    _imageUrl = iu is String && iu.toString().trim().isNotEmpty
        ? iu as String
        : null;
    _avatarUrl = _anonymous
        ? null
        : (m['author_avatar_url'] is String
              ? m['author_avatar_url'] as String
              : null);
    _avatarInitial = _anonymous ? '?' : _initialFromApi(m['author_initial']);
    _likes = _parseInt(m['likes_count'], _likes);
    _dislikes = _parseInt(m['dislikes_count'], _dislikes);
    final dynamic vr = m['viewer_reaction'];
    _viewer = vr is String ? vr : null;
    _serverCommentsCount = _parseInt(m['comments_count'], _serverCommentsCount);
  }

  Future<void> _fetchPostDetail({bool quiet = false}) async {
    if (widget.postId < 0) {
      return;
    }
    if (!quiet) {
      setState(() {
        _loadingDetail = true;
      });
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = (prefs.getString('session_access_token') ?? '')
          .trim();
      final Uri uri = Uri.parse(
        '${widget.apiBaseUrl}/api/v1/posts/${widget.postId}',
      );
      final Map<String, String> headers = <String, String>{
        'X-API-Key': _apiKey,
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final http.Response res = await http.get(uri, headers: headers);
      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _applyDetailJson(decoded);
            if (!quiet) {
              _loadingDetail = false;
            }
          });
          return;
        }
      }
      if (res.statusCode == 404) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post not found.')));
      }
      setState(() {
        if (!quiet) {
          _loadingDetail = false;
        }
      });
    } catch (e) {
      if (mounted) {
        if (!quiet) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not refresh post: $e')));
        }
        setState(() {
          if (!quiet) {
            _loadingDetail = false;
          }
        });
      }
    }
  }

  Future<void> _fetchComments() async {
    if (widget.postId < 0) {
      return;
    }
    setState(() {
      _loadingComments = true;
      _commentsLoadError = null;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = (prefs.getString('session_access_token') ?? '')
          .trim();
      final Uri uri = Uri.parse(
        '${widget.apiBaseUrl}/api/v1/posts/${widget.postId}/comments',
      );
      final Map<String, String> headers = <String, String>{
        'X-API-Key': _apiKey,
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final http.Response res = await http.get(uri, headers: headers);
      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> &&
            decoded['items'] is List<dynamic>) {
          final List<dynamic> items = decoded['items'] as List<dynamic>;
          setState(() {
            _roots = items
                .whereType<Map<String, dynamic>>()
                .map(_CommentVm.fromJson)
                .where((c) => c.id > 0)
                .toList();
            _loadingComments = false;
            _commentsLoadError = null;
          });
          return;
        }
      }
      if (res.statusCode == 404) {
        setState(() {
          _commentsLoadError = 'Post not found.';
          _loadingComments = false;
        });
        return;
      }
      setState(() {
        _commentsLoadError = 'Comments load failed (${res.statusCode}).';
        _loadingComments = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _commentsLoadError = '$e';
          _loadingComments = false;
        });
      }
    }
  }

  Future<void> _postCommentToApi(String text, int? parentId) async {
    if (widget.postId < 0 || _postingComment) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = (prefs.getString('session_access_token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle login karo — phir comment kar sakte ho.'),
        ),
      );
      return;
    }

    setState(() {
      _postingComment = true;
    });

    try {
      final Uri uri = Uri.parse(
        '${widget.apiBaseUrl}/api/v1/posts/${widget.postId}/comments',
      );
      final Map<String, dynamic> payload = <String, dynamic>{'body': text};
      if (parentId != null) {
        payload['parent_id'] = parentId;
      }
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'X-API-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) {
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment save nahi hua (${res.statusCode}).')),
        );
        return;
      }
      _replyController.clear();
      await Future.wait(<Future<void>>[
        _fetchComments(),
        _fetchPostDetail(quiet: true),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _postingComment = false;
        });
      }
    }
  }

  String _commentAuthorLine(_CommentVm c) {
    final String co = c.company.trim();
    if (co.isNotEmpty) {
      return '${c.authorDisplay} • $co';
    }
    return c.authorDisplay;
  }

  String _commentVisibleBody(_CommentVm c) {
    final bool on = _commentTranslated[c.id] == true;
    if (on) {
      return _commentTranslatedText[c.id] ?? c.body;
    }
    return c.body;
  }

  Future<void> _toggleCommentTranslationById(
    int commentId,
    String originalBody,
  ) async {
    if (_commentTranslating[commentId] == true) {
      return;
    }
    if (_commentTranslated[commentId] == true) {
      setState(() {
        _commentTranslated[commentId] = false;
      });
      return;
    }
    if (originalBody.trim().isEmpty) {
      return;
    }
    setState(() {
      _commentTranslating[commentId] = true;
    });
    try {
      final String from = _detectSupportedLanguage(originalBody);
      final String to = from == 'hi' ? 'en' : 'hi';
      final Translation result = await _commentTranslator.translate(
        originalBody,
        from: from,
        to: to,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _commentTranslatedText[commentId] = result.text;
        _commentTranslated[commentId] = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation failed. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _commentTranslating[commentId] = false;
        });
      }
    }
  }

  Future<void> _submitReactionTap(String side) async {
    if (widget.postId < 0 || _reactionBusy) {
      return;
    }

    final String kind;
    if (side == 'like') {
      kind = _viewer == 'like' ? 'none' : 'like';
    } else {
      kind = _viewer == 'dislike' ? 'none' : 'dislike';
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = (prefs.getString('session_access_token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle login karo — phir like/dislike kar sakte ho.'),
        ),
      );
      return;
    }

    setState(() {
      _reactionBusy = true;
      _busySide = side;
    });

    try {
      final Uri uri = Uri.parse(
        '${widget.apiBaseUrl}/api/v1/posts/${widget.postId}/reaction',
      );
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'X-API-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{'kind': kind}),
      );

      if (!mounted) {
        return;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reaction save nahi hua (${res.statusCode}).'),
          ),
        );
        return;
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final int likes = decoded['likes_count'] is int
          ? decoded['likes_count'] as int
          : int.tryParse('${decoded['likes_count']}') ?? _likes;
      final int dislikes = decoded['dislikes_count'] is int
          ? decoded['dislikes_count'] as int
          : int.tryParse('${decoded['dislikes_count']}') ?? _dislikes;
      final dynamic vr = decoded['viewer_reaction'];
      final String? viewer = vr is String ? vr : null;

      setState(() {
        _likes = likes;
        _dislikes = dislikes;
        _viewer = viewer;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _reactionBusy = false;
          _busySide = null;
        });
      }
    }
  }

  Widget _reactionLeadingIcon({
    required bool selected,
    required IconData filled,
    required IconData outlined,
    required String side,
    required bool isDark,
  }) {
    if (_reactionBusy && _busySide == side) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: selected
              ? Colors.white
              : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
        ),
      );
    }
    return Icon(
      selected ? filled : outlined,
      size: 14,
      color: selected
          ? Colors.white
          : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
    );
  }

  Widget _buildAuthorAvatar(List<Color> avatarColors, bool isDark) {
    if (_anonymous) {
      return _avatarShell(
        avatarColors: avatarColors,
        child: const Icon(
          Icons.visibility_off_rounded,
          color: Colors.white,
          size: 22,
        ),
      );
    }
    final String? url = _avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: avatarColors.last.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _letterAvatar(avatarColors),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                width: 46,
                height: 46,
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF1F5F9),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF0B1F3A),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return _letterAvatar(avatarColors);
  }

  Widget _avatarShell({
    required List<Color> avatarColors,
    required Widget child,
  }) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: avatarColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: avatarColors.last.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _letterAvatar(List<Color> avatarColors) {
    final String raw = _avatarInitial.trim();
    final String letter = raw.isNotEmpty
        ? raw.substring(0, 1).toUpperCase()
        : '?';
    return _avatarShell(
      avatarColors: avatarColors,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> avatarColors = _anonymous
        ? const [Color(0xFF64748B), Color(0xFF334155)]
        : const [Color(0xFF0B1F3A), Color(0xFFFFC928)];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1220)
          : const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0B1F3A),
        title: Text(
          'Post View',
          style: TextStyle(
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0B1F3A),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait(<Future<void>>[
            _fetchPostDetail(quiet: true),
            _fetchComments(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            if (_loadingDetail)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF1F2937), Color(0xFF111827)]
                      : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0x335B6B88)
                      : const Color(0x3394A3B8),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 20,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildAuthorAvatar(avatarColors, isDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _author,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark ? const Color(0xFFE5E7EB) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF1E3A8A,
                                      ).withValues(alpha: 0.35)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$_company • $_city',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFBFDBFE)
                                      : const Color(0xFF0B1F3A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _mainTranslated
                        ? (_mainTranslatedText ?? _displayBody)
                        : _displayBody,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF1B2A44),
                    ),
                  ),
                  if (_displayBody.trim().length > _detailLongTextThreshold)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(top: 6, bottom: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Show less',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A),
                          ),
                        ),
                      ),
                    ),
                  if (_imageUrl != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x160F172A),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(_imageUrl!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '# $tag',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF1B2A44),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0x22FFB300)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: _reactionBusy
                            ? null
                            : () => _submitReactionTap('like'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _viewer == 'like'
                                ? const Color(0xFF0B1F3A)
                                : (isDark
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFF7FAFF)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _viewer == 'like'
                                  ? const Color(0xFF0B1F3A)
                                  : (isDark
                                        ? const Color(0x335B6B88)
                                        : const Color(0x3394A3B8)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _reactionLeadingIcon(
                                selected: _viewer == 'like',
                                filled: Icons.thumb_up_rounded,
                                outlined: Icons.thumb_up_outlined,
                                side: 'like',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Like ($_likes)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _viewer == 'like'
                                      ? Colors.white
                                      : (isDark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF0B1F3A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _reactionBusy
                            ? null
                            : () => _submitReactionTap('dislike'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _viewer == 'dislike'
                                ? const Color(0xFFDC2626)
                                : (isDark
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFF7FAFF)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _viewer == 'dislike'
                                  ? const Color(0xFFDC2626)
                                  : (isDark
                                        ? const Color(0x335B6B88)
                                        : const Color(0x3394A3B8)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _reactionLeadingIcon(
                                selected: _viewer == 'dislike',
                                filled: Icons.thumb_down_rounded,
                                outlined: Icons.thumb_down_outlined,
                                side: 'dislike',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Dislike ($_dislikes)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _viewer == 'dislike'
                                      ? Colors.white
                                      : (isDark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF0B1F3A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _PostActionButton(
                        icon: Icons.translate_rounded,
                        label: _mainTranslating
                            ? 'Translating...'
                            : (_mainTranslated ? 'Original' : 'Translate'),
                        color: const Color(0xFF0F766E),
                        onTap: _mainTranslating
                            ? () {}
                            : _toggleMainPostTranslation,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF1F2937), Color(0xFF111827)]
                      : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0x335B6B88)
                      : const Color(0x3394A3B8),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_rounded,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF0B1F3A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Discussion',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                            color: isDark
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF0B1F3A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x4047B5FF)
                                : const Color(0x55FFB300),
                          ),
                        ),
                        child: Text(
                          '$_replyHeaderCount',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF0B1F3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      _replyHeaderCount == 1
                          ? '1 reply'
                          : '$_replyHeaderCount replies',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF5B6473),
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? const Color(0x22E5E7EB)
                        : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 12),
                  if (_commentsLoadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _fetchComments,
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_commentsLoadError Tap to retry.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_loadingComments &&
                      _roots.isEmpty &&
                      _commentsLoadError == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_loadingComments &&
                      _roots.isEmpty &&
                      _commentsLoadError == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Abhi koi reply nahi — pehla comment likho.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF5B6473),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ..._roots.map((c) => _buildRootCommentCard(c, isDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_postingComment,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Comment likho…',
                      isDense: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFFFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0x335B6B88)
                              : const Color(0x3394A3B8),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0x335B6B88)
                              : const Color(0x3394A3B8),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF0B1F3A),
                          width: 1.3,
                        ),
                      ),
                      suffixIcon: _postingComment
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _submitTopLevelComment,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF0B1F3A),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitTopLevelComment() async {
    final String text = _replyController.text.trim();
    if (text.isEmpty || _postingComment) {
      return;
    }
    await _postCommentToApi(text, null);
  }

  Future<void> _openReplySheet(
    _CommentVm threadRoot, {
    _CommentVm? quoting,
  }) async {
    final TextEditingController controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quoting == null
                    ? 'Reply to ${_commentAuthorLine(threadRoot)}'
                    : 'Reply in thread',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (quoting != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Thread: ${_commentAuthorLine(threadRoot)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Referencing: ${_commentAuthorLine(quoting)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _postingComment
                      ? null
                      : () async {
                          final String reply = controller.text.trim();
                          if (reply.isEmpty) {
                            return;
                          }
                          Navigator.of(ctx).pop();
                          await _postCommentToApi(reply, threadRoot.id);
                        },
                  child: const Text('Send reply'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  Widget _buildRootCommentCard(_CommentVm c, bool isDark) {
    final List<Widget> threadChildren = <Widget>[];
    for (int i = 0; i < c.replies.length; i++) {
      final _CommentVm r = c.replies[i];
      if (i > 0) {
        threadChildren.add(SizedBox(height: isDark ? 10 : 12));
      }
      threadChildren.add(
        _ThreadedReplyRow(
          isDark: isDark,
          authorLine: _commentAuthorLine(r),
          timeLabel: _formatCommentRelativeTime(r.createdAtIso),
          body: _commentVisibleBody(r),
          isTranslating: _commentTranslating[r.id] == true,
          translateLabel: _commentTranslating[r.id] == true
              ? 'Translating...'
              : (_commentTranslated[r.id] == true ? 'Original' : 'Translate'),
          onReplyTap: () => _openReplySheet(c, quoting: r),
          onTranslateTap: () => _toggleCommentTranslationById(r.id, r.body),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _RootCommentCard(
        isDark: isDark,
        authorLine: _commentAuthorLine(c),
        timeLabel: _formatCommentRelativeTime(c.createdAtIso),
        body: _commentVisibleBody(c),
        isTranslating: _commentTranslating[c.id] == true,
        translateLabel: _commentTranslating[c.id] == true
            ? 'Translating...'
            : (_commentTranslated[c.id] == true ? 'Original' : 'Translate'),
        onReplyTap: () => _openReplySheet(c),
        onTranslateTap: () => _toggleCommentTranslationById(c.id, c.body),
        threadBlock: c.replies.isEmpty
            ? null
            : _RepliesThreadBlock(
                isDark: isDark,
                replyCount: c.replies.length,
                children: threadChildren,
              ),
      ),
    );
  }

  String _detectSupportedLanguage(String text) {
    final RegExp devanagariRegex = RegExp(r'[\u0900-\u097F]');
    return devanagariRegex.hasMatch(text) ? 'hi' : 'en';
  }

  Future<void> _toggleMainPostTranslation() async {
    if (_mainTranslated) {
      setState(() {
        _mainTranslated = false;
      });
      return;
    }

    setState(() {
      _mainTranslating = true;
    });

    try {
      final String from = _detectSupportedLanguage(_displayBody);
      final String to = from == 'hi' ? 'en' : 'hi';
      final Translation result = await _commentTranslator.translate(
        _displayBody,
        from: from,
        to: to,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _mainTranslatedText = result.text;
        _mainTranslated = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post translation failed. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _mainTranslating = false;
        });
      }
    }
  }
}

class _RootCommentCard extends StatelessWidget {
  const _RootCommentCard({
    required this.isDark,
    required this.authorLine,
    required this.timeLabel,
    required this.body,
    required this.isTranslating,
    required this.translateLabel,
    required this.onReplyTap,
    required this.onTranslateTap,
    this.threadBlock,
  });

  final bool isDark;
  final String authorLine;
  final String timeLabel;
  final String body;
  final bool isTranslating;
  final String translateLabel;
  final VoidCallback onReplyTap;
  final VoidCallback onTranslateTap;
  final Widget? threadBlock;

  @override
  Widget build(BuildContext context) {
    final Color accent = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF0B1F3A);
    final Color cardBg = isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color borderCol = isDark
        ? const Color(0x335B6B88)
        : const Color(0x3394A3B8);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x14000000) : const Color(0x0A0F172A),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          authorLine,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.25,
                            color: isDark
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            timeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.2,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF5B6473),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF2C3E57),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PostActionButton(
                        icon: Icons.reply_rounded,
                        label: 'Reply',
                        color: const Color(0xFF0B1F3A),
                        onTap: onReplyTap,
                      ),
                      _PostActionButton(
                        icon: Icons.translate_rounded,
                        label: translateLabel,
                        color: isTranslating
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFF0F766E),
                        onTap: isTranslating ? () {} : onTranslateTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (threadBlock != null) threadBlock!,
        ],
      ),
    );
  }
}

class _RepliesThreadBlock extends StatelessWidget {
  const _RepliesThreadBlock({
    required this.isDark,
    required this.replyCount,
    required this.children,
  });

  final bool isDark;
  final int replyCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Color wellBg = isDark
        ? const Color(0xFF0C1222)
        : const Color(0xFFF8FAFD);
    final Color borderTop = isDark
        ? const Color(0x335B6B88)
        : const Color(0xFFE2E8F0);
    final Color iconColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF5B6473);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: wellBg,
        border: Border(top: BorderSide(color: borderTop, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 17, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  replyCount == 1
                      ? '1 reply in thread'
                      : '$replyCount replies in thread',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ThreadedReplyRow extends StatelessWidget {
  const _ThreadedReplyRow({
    required this.isDark,
    required this.authorLine,
    required this.timeLabel,
    required this.body,
    required this.isTranslating,
    required this.translateLabel,
    required this.onReplyTap,
    required this.onTranslateTap,
  });

  final bool isDark;
  final String authorLine;
  final String timeLabel;
  final String body;
  final bool isTranslating;
  final String translateLabel;
  final VoidCallback onReplyTap;
  final VoidCallback onTranslateTap;

  @override
  Widget build(BuildContext context) {
    final Color rail = isDark
        ? const Color(0xFF14B8A6)
        : const Color(0xFFFFC928);
    final Color replyBg = isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final Color borderCol = isDark
        ? const Color(0x285B6B88)
        : const Color(0x3394A3B8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: rail,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: replyBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        authorLine,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.2,
                          color: isDark
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.2,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF5B6473),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF2C3E57),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PostActionButton(
                      icon: Icons.reply_rounded,
                      label: 'Reply',
                      color: const Color(0xFF0B1F3A),
                      onTap: onReplyTap,
                    ),
                    _PostActionButton(
                      icon: Icons.translate_rounded,
                      label: translateLabel,
                      color: isTranslating
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFF0F766E),
                      onTap: isTranslating ? () {} : onTranslateTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isActive
        ? color
        : (isDark
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.09));
    final Color textColor = isActive
        ? Colors.white
        : (isDark ? Colors.white : color);
    final Color borderColor = isActive
        ? color
        : (isDark
              ? color.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.14));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

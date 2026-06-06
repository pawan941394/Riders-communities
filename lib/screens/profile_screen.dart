import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.onProfileSynced,
    required this.displayName,
    required this.username,
    required this.profileImageUrl,
    this.languageCode = 'en',
  });

  final VoidCallback onLogout;
  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final ValueChanged<Map<String, dynamic>>? onProfileSynced;
  final String displayName;
  final String username;
  final String profileImageUrl;
  final String languageCode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<List<Color>> _cardGradients = [
    [Color(0xFF2563EB), Color(0xFF06B6D4)],
    [Color(0xFF7C3AED), Color(0xFF2563EB)],
    [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
    [Color(0xFF2563EB), Color(0xFF4F46E5)],
    [Color(0xFF0891B2), Color(0xFF2563EB)],
    [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
  ];

  bool _loadingProfile = true;
  bool _loadingPosts = true;
  String? _loadError;

  String _displayName = '';
  String _usernameHandle = '';
  String _bio = '';
  String? _profileImagePath;
  Uint8List? _profileImageBytes;

  int _postsCount = 0;

  final List<Map<String, dynamic>> _myPosts = [];
  bool get _isHindi => widget.languageCode.toLowerCase().startsWith('hi');
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _displayName = widget.displayName;
    _usernameHandle = widget.username;
    if (widget.profileImageUrl.isNotEmpty) {
      _profileImagePath = widget.profileImageUrl;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.profileImageUrl != widget.profileImageUrl ||
        oldWidget.displayName != widget.displayName ||
        oldWidget.username != widget.username) {
      _displayName = widget.displayName;
      _usernameHandle = widget.username;
      if (widget.profileImageUrl.isNotEmpty) {
        _profileImagePath = widget.profileImageUrl;
        _profileImageBytes = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
    }
  }

  Future<void> _refreshAll() async {
    if (widget.accessToken.isEmpty) {
      setState(() {
        _loadingProfile = false;
        _loadingPosts = false;
        _loadError = _tr('Session missing - log in again.', 'सेशन नहीं मिला - दोबारा लॉगिन करें।');
      });
      return;
    }
    await Future.wait<void>([_fetchProfile(), _fetchMyPosts()]);
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });
    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/auth/me');
      final http.Response res = await http.get(
        uri,
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loadingProfile = false;
          _loadError = _tr(
            'Profile load failed (${res.statusCode}).',
            'प्रोफाइल लोड नहीं हुआ (${res.statusCode})।',
          );
        });
        return;
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _loadingProfile = false;
          _loadError = _tr('Invalid profile response.', 'प्रोफाइल का जवाब अमान्य है।');
        });
        return;
      }
      final dynamic profileRaw = decoded['profile'];
      final dynamic statsRaw = decoded['stats'];
      if (profileRaw is! Map<String, dynamic>) {
        setState(() {
          _loadingProfile = false;
          _loadError = _tr('Invalid profile payload.', 'प्रोफाइल डेटा अमान्य है।');
        });
        return;
      }
      final String fullName = ('${profileRaw['full_name'] ?? ''}').trim();
      final String username = ('${profileRaw['username'] ?? ''}').trim();
      final String photo = ('${profileRaw['profile_photo_url'] ?? ''}').trim();
      final String bio = ('${profileRaw['bio'] ?? ''}').trim();

      final String showName =
          fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : widget.displayName);
      final String handle = username.isNotEmpty ? '@$username' : widget.username;

      int posts = 0;
      if (statsRaw is Map<String, dynamic>) {
        posts = statsRaw['posts_count'] is int ? statsRaw['posts_count'] as int : int.tryParse('${statsRaw['posts_count']}') ?? 0;
      }

      setState(() {
        _loadingProfile = false;
        _displayName = showName;
        _usernameHandle = handle;
        _bio = bio;
        if (photo.isNotEmpty) {
          _profileImagePath = photo;
          _profileImageBytes = null;
        }
        _postsCount = posts;
      });

      widget.onProfileSynced?.call(profileRaw);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _loadError = _tr('Network error loading profile.', 'प्रोफाइल लोड करते समय नेटवर्क त्रुटि हुई।');
      });
    }
  }

  Future<void> _fetchMyPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/posts/me').replace(
        queryParameters: <String, String>{'limit': '50', 'offset': '0'},
      );
      final http.Response res = await http.get(
        uri,
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loadingPosts = false;
          if (_loadError == null) {
            _loadError = _tr(
              'Posts load failed (${res.statusCode}).',
              'पोस्ट्स लोड नहीं हुए (${res.statusCode})।',
            );
          }
        });
        return;
      }
      final dynamic decoded = jsonDecode(res.body);
      final List<Map<String, dynamic>> rows = [];
      if (decoded is Map<String, dynamic> && decoded['items'] is List<dynamic>) {
        for (final dynamic item in decoded['items'] as List<dynamic>) {
          if (item is Map<String, dynamic>) rows.add(item);
        }
      }
      setState(() {
        _loadingPosts = false;
        _myPosts
          ..clear()
          ..addAll(rows);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPosts = false;
        if (_loadError == null) {
          _loadError = _tr('Network error loading posts.', 'पोस्ट्स लोड करते समय नेटवर्क त्रुटि हुई।');
        }
      });
    }
  }

  String _formatStat(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }

  List<String> _tagsFromRow(Map<String, dynamic> row) {
    final List<String> tags = <String>[];
    final dynamic t = row['tags'];
    if (t is List<dynamic>) {
      for (final dynamic x in t) {
        if (x is String && x.trim().isNotEmpty) tags.add(x.trim());
      }
    }
    if (tags.isEmpty) tags.add(_tr('Community', 'कम्युनिटी'));
    return tags;
  }

  void _openPostDetail(Map<String, dynamic> row) {
    final int postId = row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}') ?? 0;
    if (postId <= 0) return;

    final String body = '${row['body'] ?? ''}'.trim();
    final String bodyFull = '${row['body_full'] ?? row['body'] ?? ''}'.trim();
    final String city = '${row['city'] ?? ''}';
    final String company = '${row['company'] ?? ''}';
    final bool anon = row['is_anonymous'] == true;
    final List<String> tags = _tagsFromRow(row);
    final String? imageUrl = row['image_url'] is String ? row['image_url'] as String : null;
    final int comments = row['comments_count'] is int ? row['comments_count'] as int : int.tryParse('${row['comments_count']}') ?? 0;
    final int likes = row['likes_count'] is int ? row['likes_count'] as int : int.tryParse('${row['likes_count']}') ?? 0;
    final int dislikes =
        row['dislikes_count'] is int ? row['dislikes_count'] as int : int.tryParse('${row['dislikes_count']}') ?? 0;
    final String? viewerRx = row['viewer_reaction'] is String ? row['viewer_reaction'] as String : null;
    final String author = '${row['author_display'] ?? _displayName}';

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailScreen(
          postId: postId,
          apiBaseUrl: widget.apiBaseUrl,
          author: author,
          problem: body.isEmpty ? bodyFull : body,
          bodyFull: bodyFull.isNotEmpty ? bodyFull : null,
          city: city,
          company: company,
          tags: tags,
          commentsCount: comments,
          isAnonymous: anon,
          imageUrl: imageUrl,
          authorAvatarUrl: anon ? null : (row['author_avatar_url'] is String ? row['author_avatar_url'] as String : null),
          authorInitial: anon ? '?' : '${row['author_initial'] ?? '?'}',
          likesCount: likes,
          dislikesCount: dislikes,
          viewerReaction: viewerRx,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool compact = screenWidth < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _loadError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1F2937), Color(0xFF111827)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFF8E8)],
              ),
              border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x1F000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    top: -46,
                    right: -34,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0x223B82F6)
                            : const Color(0x14000000),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -58,
                    left: -22,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0x1E14B8A6)
                            : const Color(0x0F000000),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0x0FFFFFFF), Color(0x05000000)]
                              : const [Color(0x12FFFFFF), Color(0x08000000)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                if (_loadingProfile)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileAvatar(compact: compact),
                          const SizedBox(height: 10),
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _usernameHandle,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          _buildProfileAvatar(compact: compact),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _usernameHandle,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                Text(
                  _bio.isNotEmpty
                      ? _bio
                      : _tr(
                          'Add a short bio so others know how you ride - tap Edit profile.',
                          'छोटी सी बायो जोड़ें ताकि लोग जान सकें आप कैसे राइड करते हैं - Edit profile दबाएं।',
                        ),
                  style: TextStyle(
                    color: _bio.isNotEmpty
                        ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334E68))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _ProfileStatItem(label: _tr('Posts', 'पोस्ट्स'), value: _formatStat(_postsCount)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _loadingProfile ? null : _openEditProfileModal,
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(_tr('Edit profile', 'प्रोफाइल एडिट करें')),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(_tr('Logout', 'लॉगआउट')),
                    ),
                  ],
                ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _tr('Your posts', 'आपकी पोस्ट्स'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingPosts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myPosts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _tr(
                  'You have no posts yet - create your first post in Community.',
                  'अभी आपकी कोई पोस्ट नहीं है - कम्युनिटी में अपनी पहली पोस्ट बनाएं।',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 10;
                final int columns = compact ? 2 : 3;
                final double cardWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) / columns;
                final double cardHeight = compact ? 206 : 198;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List<Widget>.generate(_myPosts.length, (int i) {
                    final Map<String, dynamic> row = _myPosts[i];
                    final String title = ('${row['body'] ?? ''}').trim();
                    final String subtitle =
                        '${row['company'] ?? ''}'.trim().isEmpty ? '${row['city'] ?? ''}' : '${row['company'] ?? ''} — ${row['city'] ?? ''}';
                    final int comments =
                        row['comments_count'] is int ? row['comments_count'] as int : int.tryParse('${row['comments_count']}') ?? 0;
                    final int likes =
                        row['likes_count'] is int ? row['likes_count'] as int : int.tryParse('${row['likes_count']}') ?? 0;
                    final String? imageUrl = row['image_url'] is String ? row['image_url'] as String : null;
                    final List<Color> pair = _cardGradients[i % _cardGradients.length];

                    return SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _ProfilePostCard(
                        title: title.isEmpty ? _tr('Post', 'पोस्ट') : title,
                        subtitle: subtitle.trim().isEmpty ? '-' : subtitle.trim(),
                        comments: '$comments',
                        likes: '$likes',
                        colorA: pair[0],
                        colorB: pair[1],
                        imageUrl: imageUrl,
                        onTap: () => _openPostDetail(row),
                      ),
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar({required bool compact}) {
    return Container(
      width: compact ? 76 : 84,
      height: compact ? 76 : 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: _profileImagePath == null && _profileImageBytes == null
          ? const Icon(Icons.person_rounded, size: 36, color: Colors.white)
          : ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image(
                image: _getProfileImageProvider(
                  path: _profileImagePath,
                  bytes: _profileImageBytes,
                ),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: Colors.white,
                  );
                },
              ),
            ),
    );
  }

  Future<void> _openEditProfileModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _EditProfileModalContent(
          initialBio: _bio,
          referenceBio: _bio,
          profileImagePath: _profileImagePath,
          profileImageBytes: _profileImageBytes,
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
          getProfileImageProvider: _getProfileImageProvider,
          onPatchSuccess: (Map<String, dynamic> decoded, String nextBio, bool hasNewLocalImage, String? tempImagePath) {
            final String bio = ('${decoded['bio'] ?? nextBio}').trim();
            final String photo = ('${decoded['profile_photo_url'] ?? ''}').trim();
            setState(() {
              _bio = bio;
              _profileImageBytes = null;
              if (photo.isNotEmpty) {
                _profileImagePath = photo;
              } else if (!hasNewLocalImage) {
                _profileImagePath = tempImagePath;
              }
            });
            widget.onProfileSynced?.call(decoded);
          },
          onSuccessfulSaveRefresh: _refreshAll,
          languageCode: widget.languageCode,
        );
      },
    );
  }

  ImageProvider _getProfileImageProvider({
    required String? path,
    required Uint8List? bytes,
  }) {
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    if (path != null && (path.startsWith('http://') || path.startsWith('https://'))) {
      return NetworkImage(path);
    }
    return FileImage(File(path!));
  }
}

class _EditProfileModalContent extends StatefulWidget {
  const _EditProfileModalContent({
    required this.initialBio,
    required this.referenceBio,
    required this.profileImagePath,
    required this.profileImageBytes,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    required this.getProfileImageProvider,
    required this.onPatchSuccess,
    required this.onSuccessfulSaveRefresh,
    this.languageCode = 'en',
  });

  final String initialBio;
  final String referenceBio;
  final String? profileImagePath;
  final Uint8List? profileImageBytes;
  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final ImageProvider Function({required String? path, required Uint8List? bytes}) getProfileImageProvider;
  final void Function(
    Map<String, dynamic> decoded,
    String nextBio,
    bool hasNewLocalImage,
    String? tempImagePath,
  ) onPatchSuccess;
  final Future<void> Function() onSuccessfulSaveRefresh;
  final String languageCode;

  @override
  State<_EditProfileModalContent> createState() => _EditProfileModalContentState();
}

class _EditProfileModalContentState extends State<_EditProfileModalContent> {
  late final TextEditingController _bioController;
  late String? _tempImagePath;
  Uint8List? _tempImageBytes;
  final ImagePicker _imagePicker = ImagePicker();
  bool get _isHindi => widget.languageCode.toLowerCase().startsWith('hi');
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.initialBio);
    _tempImagePath = widget.profileImagePath;
    _tempImageBytes = widget.profileImageBytes;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String nextBio = _bioController.text.trim();
    final bool hasNewLocalImage = _tempImageBytes != null ||
        (_tempImagePath != null &&
            !_tempImagePath!.startsWith('http://') &&
            !_tempImagePath!.startsWith('https://'));

    if (!hasNewLocalImage && nextBio == widget.referenceBio) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (widget.accessToken.isEmpty) {
      return;
    }

    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/auth/profile');
      final http.MultipartRequest req = http.MultipartRequest('PATCH', uri);
      req.headers['X-API-Key'] = widget.apiAccessKey;
      req.headers['Authorization'] = 'Bearer ${widget.accessToken}';
      req.fields['bio'] = nextBio;

      if (_tempImageBytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'profile_photo',
            _tempImageBytes!,
            filename: 'profile.jpg',
          ),
        );
      } else if (hasNewLocalImage && _tempImagePath != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'profile_photo',
            _tempImagePath!,
            filename: 'profile.jpg',
          ),
        );
      }

      final http.StreamedResponse streamed = await req.send();
      final http.Response res = await http.Response.fromStream(streamed);
      if (!mounted) {
        return;
      }
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('Save failed (${res.statusCode})', 'सेव नहीं हो पाया (${res.statusCode})'),
            ),
          ),
        );
        return;
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        widget.onPatchSuccess(decoded, nextBio, hasNewLocalImage, _tempImagePath);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await widget.onSuccessfulSaveRefresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('Network error - try again.', 'नेटवर्क त्रुटि - फिर से कोशिश करें।'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr('Edit profile', 'प्रोफाइल एडिट करें'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF102A56),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                  ),
                  child: _tempImagePath == null && _tempImageBytes == null
                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Image(
                            image: widget.getProfileImageProvider(
                              path: _tempImagePath,
                              bytes: _tempImageBytes,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                              return const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 32,
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final XFile? selected = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 1600,
                          );
                          if (selected == null) {
                            return;
                          }
                          if (kIsWeb) {
                            final Uint8List data = await selected.readAsBytes();
                            setState(() {
                              _tempImageBytes = data;
                              _tempImagePath = null;
                            });
                            return;
                          }
                          setState(() {
                            _tempImagePath = selected.path;
                            _tempImageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(_tr('Gallery', 'गैलरी')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final XFile? selected = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                            maxWidth: 1600,
                          );
                          if (selected == null) {
                            return;
                          }
                          if (kIsWeb) {
                            final Uint8List data = await selected.readAsBytes();
                            setState(() {
                              _tempImageBytes = data;
                              _tempImagePath = null;
                            });
                            return;
                          }
                          setState(() {
                            _tempImagePath = selected.path;
                            _tempImageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: Text(_tr('Camera', 'कैमरा')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              minLines: 2,
              maxLines: 4,
              style: TextStyle(
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                labelText: _tr('Bio', 'बायो'),
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : null,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? const Color(0x335B6B88) : const Color(0x331D4ED8),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.accessToken.isEmpty ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_tr('Save', 'सेव करें')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  const _ProfileStatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D4ED8),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.title,
    required this.subtitle,
    required this.comments,
    required this.likes,
    required this.colorA,
    required this.colorB,
    this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String comments;
  final String likes;
  final Color colorA;
  final Color colorB;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: imageUrl == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorA, colorB],
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: colorA.withValues(alpha: 0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: imageUrl != null
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x26000000), Color(0xD1000000)],
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0x36FFFFFF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0x45FFFFFF)),
                    ),
                    child: Icon(
                      imageUrl != null ? Icons.image_rounded : Icons.article_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xE8FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x2AFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x36FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(comments, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        const SizedBox(width: 10),
                        const Icon(Icons.favorite_border_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(likes, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async' show Timer, unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'buy_ev_screen.dart';
import 'contact_screen.dart';
import 'rent_ev_screen.dart';
import 'rsa_screen.dart';
import '../inquiry_icons.dart';
import '../services/contact_api.dart';
import '../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLogout,
    required this.accessToken,
    this.onProfileSynced,
    required this.currentUserName,
    required this.currentUserHandle,
    required this.currentUserAvatarUrl,
    required this.currentUserCity,
    required this.currentUserPhone,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLogout;
  final String accessToken;
  final ValueChanged<Map<String, dynamic>>? onProfileSynced;
  final String currentUserName;
  final String currentUserHandle;
  final String currentUserAvatarUrl;
  final String currentUserCity;
  final String currentUserPhone;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const String _kLastSeenNotificationId = 'last_seen_notification_id';
  int _currentIndex = 0;
  Timer? _notificationsTimer;
  bool _notificationFetching = false;
  int _lastSeenNotificationId = 0;
  final List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  int _unreadNotifications = 0;
  String _languageCode = 'en';
  bool _languageSaving = false;

  static const String _shellApiAccessKey = ApiConfig.apiAccessKey;

  String get _shellApiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  bool get _isHindi => _languageCode == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapNotifications());
    unawaited(_loadLanguagePreference());
    _notificationsTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_checkNotifications()),
    );
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final screens = [
      CommunityFeedScreen(
        initialCity: widget.currentUserCity.trim(),
        accessToken: widget.accessToken,
        languageCode: _languageCode,
        onOpenCreatePost: () {
          setState(() {
            _currentIndex = 7;
          });
        },
        onOpenRefer: () {
          setState(() {
            _currentIndex = 4;
          });
        },
      ),
      RsaScreen(
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        languageCode: _languageCode,
        initialPhone: widget.currentUserPhone,
        onOpenOnboarding: () {
          setState(() {
            _currentIndex = 2;
          });
        },
      ),
      RiderOnboardingDetailsScreen(
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        languageCode: _languageCode,
        onCompleted: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      EvScreen(
        currentUserCity: widget.currentUserCity,
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        languageCode: _languageCode,
      ),
      WalletScreen(
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        languageCode: _languageCode,
      ),
      HelpScreen(
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        languageCode: _languageCode,
      ),
      ProfileScreen(
        onLogout: widget.onLogout,
        apiBaseUrl: _shellApiBaseUrl,
        apiAccessKey: _shellApiAccessKey,
        accessToken: widget.accessToken,
        onProfileSynced: widget.onProfileSynced,
        displayName: widget.currentUserName,
        username: widget.currentUserHandle,
        profileImageUrl: widget.currentUserAvatarUrl,
        languageCode: _languageCode,
      ),
      CreatePostScreen(
        initialCity: widget.currentUserCity.trim().isEmpty ? null : widget.currentUserCity.trim(),
      ),
    ];
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: isDark ? const Color(0xFF0B1220) : null,
      drawer: _buildAppDrawer(isDark),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0B1220), Color(0xFF111827)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2937).withValues(alpha: 0.92)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x335B6B88) : const Color(0x1F000000),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: 'Open menu',
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            icon: _HamburgerGlyph(
                              color: isDark ? const Color(0xFFE2E8F0) : Colors.black,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937).withValues(alpha: 0.92)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.transparent : const Color(0x1F000000),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    tooltip: 'Notifications',
                                    onPressed: _openNotificationsSheet,
                                    icon: Icon(
                                      Icons.notifications_rounded,
                                      color: isDark ? const Color(0xFFE2E8F0) : Colors.black,
                                    ),
                                  ),
                                  if (_unreadNotifications > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937).withValues(alpha: 0.92)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.transparent : const Color(0x1F000000),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() {
                                    _currentIndex = 6;
                                  });
                                },
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      isDark ? const Color(0xFF1E293B) : Colors.white,
                                  backgroundImage: widget.currentUserAvatarUrl.isNotEmpty
                                      ? NetworkImage(widget.currentUserAvatarUrl)
                                      : null,
                                  child: widget.currentUserAvatarUrl.isEmpty
                                      ? const Icon(Icons.person_rounded, color: Colors.black)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: Text(
                        'Rider',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFE2E8F0) : Colors.black,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentIndex),
                    child: screens[_currentIndex],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xF11E293B), Color(0xED0F172A)]
                  : const [Color(0xF2FFF7DE), Color(0xE8FFF2C2)],
            ),
            border: Border.all(
              color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 360;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.groups_rounded,
                        label: _tr('Community', 'कम्युनिटी'),
                        compact: compact,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.health_and_safety_rounded,
                        label: _tr('RSA', 'आरएसए'),
                        compact: compact,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.add_box_rounded,
                        label: _tr('Onboarding', 'ऑनबोर्डिंग'),
                        compact: compact,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.electric_bike_rounded,
                        label: _tr('EV', 'ईवी'),
                        compact: compact,
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.currency_rupee_rounded,
                        label: _tr('Refer', 'रेफर'),
                        compact: compact,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer(bool isDark) {
    final Color background = isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final Color titleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color bodyColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color dividerColor = isDark ? const Color(0x1F5B6B88) : const Color(0x0F000000);

    return Drawer(
      backgroundColor: background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            // Premium Profile Cover Card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFFFF3D1), const Color(0xFFFFB300)], // Premium golden yellow theme!
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black38 : const Color(0xFFFFB300).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white : const Color(0xFF0B1F3A).withValues(alpha: 0.8), // elegant ring
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFFFFFFF),
                      backgroundImage: widget.currentUserAvatarUrl.isNotEmpty
                          ? NetworkImage(widget.currentUserAvatarUrl)
                          : null,
                      child: widget.currentUserAvatarUrl.isEmpty
                          ? Icon(Icons.person_rounded, color: isDark ? Colors.white : const Color(0xFF0B1F3A), size: 28)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ride With Garv',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0B1F3A),
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : const Color(0xFF0B1F3A).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.currentUserName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0B1F3A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Active dot
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981), // Green active dot
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.groups_rounded,
              label: _tr('Community', 'कम्युनिटी'),
              index: 0,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.add_box_rounded,
              label: _tr('Onboarding', 'ऑनबोर्डिंग'),
              index: 2,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.electric_bike_rounded,
              label: 'EV',
              index: 3,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.currency_rupee_rounded,
              label: _tr('Refer n earn', 'रेफर और कमाओ'),
              index: 4,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.add_box_rounded,
              label: _tr('Create post', 'पोस्ट बनाएं'),
              index: 7,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.support_agent_rounded,
              label: _tr('Help', 'मदद'),
              index: 5,
              isDark: isDark,
            ),
            _buildDrawerItem(
              icon: Icons.person_rounded,
              label: _tr('Profile', 'प्रोफाइल'),
              index: 6,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            Divider(color: dividerColor, thickness: 1),
            const SizedBox(height: 8),
            // Premium settings card blocks
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: isDark ? const Color(0x13FFFFFF) : const Color(0x06000000),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: dividerColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Icon(
                    Icons.language_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  title: Text(
                    _tr('Language', 'भाषा'),
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    _languageCode == 'hi' ? 'हिंदी' : 'English',
                    style: TextStyle(color: bodyColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EN',
                        style: TextStyle(
                          color: _languageCode == 'en' ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)) : bodyColor,
                          fontWeight: _languageCode == 'en' ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 28,
                        child: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _languageCode == 'hi',
                            activeColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            onChanged: _languageSaving
                                ? null
                                : (bool value) {
                                    unawaited(_setLanguagePreference(value ? 'hi' : 'en'));
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'HI',
                        style: TextStyle(
                          color: _languageCode == 'hi' ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)) : bodyColor,
                          fontWeight: _languageCode == 'hi' ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: isDark ? const Color(0x13FFFFFF) : const Color(0x06000000),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: dividerColor),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  secondary: Icon(
                    widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: widget.isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                  ),
                  title: Text(
                    widget.isDarkMode ? _tr('Dark theme', 'डार्क थीम') : _tr('Light theme', 'लाइट थीम'),
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  value: widget.isDarkMode,
                  activeColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  onChanged: widget.onThemeChanged,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: const Color(0x0AEF4444), // very soft red background
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0x1AEF4444)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: Text(
                    _tr('Logout', 'लॉगआउट'),
                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onLogout();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _currentIndex == index;
    final Color foreground = isSelected
        ? (isDark ? Colors.white : const Color(0xFF0B1F3A))
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));
    final List<Color> selectedGradient = isDark
        ? [const Color(0xFFD97706), const Color(0xFFB45309)]
        : [const Color(0xFFFFF3D1), const Color(0xFFFFD54F)];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: selectedGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedGradient[1].withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
          leading: Icon(
            icon,
            color: foreground,
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.chevron_right_rounded, color: foreground, size: 20)
              : Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0x66CBD5E1) : const Color(0x66334155),
                  size: 20,
                ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: () {
            Navigator.of(context).pop();
            unawaited(_selectTab(index));
          },
        ),
      ),
    );
  }

  Future<void> _bootstrapNotifications() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _lastSeenNotificationId = prefs.getInt(_kLastSeenNotificationId) ?? 0;
    } catch (_) {}
    await _checkNotifications();
  }

  Future<void> _loadLanguagePreference() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    try {
      final http.Response response = await http.get(
        Uri.parse('$_shellApiBaseUrl/api/v1/language/me'),
        headers: <String, String>{
          'X-API-Key': _shellApiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final String code = ('${decoded['language_code'] ?? 'en'}').trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _languageCode = code == 'hi' ? 'hi' : 'en';
      });
    } catch (_) {}
  }

  Future<void> _setLanguagePreference(String nextCode) async {
    if (_languageSaving) return;
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    final String normalized = nextCode == 'hi' ? 'hi' : 'en';
    final String previous = _languageCode;

    setState(() {
      _languageCode = normalized;
      _languageSaving = true;
    });
    try {
      final http.Response response = await http.post(
        Uri.parse('$_shellApiBaseUrl/api/v1/language/set'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-API-Key': _shellApiAccessKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{'language_code': normalized}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) {
          setState(() {
            _languageCode = previous;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _languageCode = previous;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _languageSaving = false;
        });
      }
    }
  }

  Future<void> _saveLastSeenNotificationId(int id) async {
    if (id <= _lastSeenNotificationId) return;
    _lastSeenNotificationId = id;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSeenNotificationId, id);
    } catch (_) {}
  }

  Future<void> _markNotificationRead(int id, {String source = 'broadcast'}) async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_shellApiBaseUrl/api/v1/notifications/$id/read?source=$source'),
        headers: <String, String>{
          'X-API-Key': _shellApiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }

  Future<void> _showBroadcastNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_markNotificationRead(id));
              },
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
    await _saveLastSeenNotificationId(id);
  }

  Future<void> _checkNotifications() async {
    if (_notificationFetching) return;
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    _notificationFetching = true;
    try {
      final http.Response response = await http.get(
        Uri.parse('$_shellApiBaseUrl/api/v1/notifications/inbox?limit=25'),
        headers: <String, String>{
          'X-API-Key': _shellApiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final dynamic rawItems = decoded['items'];
      if (rawItems is! List<dynamic>) return;

      final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
      int unread = 0;
      for (final dynamic item in rawItems) {
        if (item is! Map) continue;
        final Map<String, dynamic> row = item.map<String, dynamic>(
          (dynamic k, dynamic v) => MapEntry<String, dynamic>('$k', v),
        );
        if (row['is_read'] != true) unread += 1;
        parsed.add(row);
      }
      if (mounted) {
        setState(() {
          _notifications
            ..clear()
            ..addAll(parsed);
          _unreadNotifications = unread;
        });
      }
      if (parsed.isEmpty) return;

      Map<String, dynamic>? candidate;
      for (final Map<String, dynamic> row in parsed) {
        final int id = int.tryParse('${row['id'] ?? 0}') ?? 0;
        final bool isRead = row['is_read'] == true;
        final String source = ('${row['source'] ?? 'broadcast'}').trim().toLowerCase();
        if (source == 'broadcast' && id > _lastSeenNotificationId && !isRead) {
          candidate = row;
          break;
        }
      }
      if (candidate == null) return;
      final int id = int.tryParse('${candidate['id'] ?? 0}') ?? 0;
      if (id <= 0) return;
      final String title = ('${candidate['title'] ?? ''}').trim();
      final String body = ('${candidate['body'] ?? ''}').trim();
      if (title.isEmpty && body.isEmpty) return;
      await _showBroadcastNotification(
        id: id,
        title: title.isEmpty ? 'Notification' : title,
        body: body.isEmpty ? 'You have a new update.' : body,
      );
    } catch (_) {
      // Silent fail: notifications should never block main app flow.
    } finally {
      _notificationFetching = false;
    }
  }

  Future<void> _openPostDetailFromNotification(int postId) async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    try {
      final http.Response res = await http.get(
        Uri.parse('$_shellApiBaseUrl/api/v1/posts/$postId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-API-Key': _shellApiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode != 200) return;
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;

      final String author = ('${decoded['author_display'] ?? 'Rider'}').trim();
      final String problem = ('${decoded['body'] ?? ''}').trim();
      final String city = ('${decoded['city'] ?? ''}').trim();
      final String company = ('${decoded['company'] ?? ''}').trim();
      final bool isAnonymous = decoded['is_anonymous'] == true;
      final List<String> tags = decoded['tags'] is List<dynamic>
          ? (decoded['tags'] as List<dynamic>)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final int commentsCount = decoded['comments_count'] is int
          ? decoded['comments_count'] as int
          : int.tryParse('${decoded['comments_count']}') ?? 0;
      final int likesCount = decoded['likes_count'] is int
          ? decoded['likes_count'] as int
          : int.tryParse('${decoded['likes_count']}') ?? 0;
      final int dislikesCount = decoded['dislikes_count'] is int
          ? decoded['dislikes_count'] as int
          : int.tryParse('${decoded['dislikes_count']}') ?? 0;
      final String? imageUrl = decoded['image_url'] is String ? decoded['image_url'] as String : null;
      final String? bodyFull = decoded['body_full'] is String ? decoded['body_full'] as String : null;
      final String? authorAvatarUrl =
          decoded['author_avatar_url'] is String ? decoded['author_avatar_url'] as String : null;
      final String authorInitial = ('${decoded['author_initial'] ?? '?'}').trim().isEmpty
          ? '?'
          : '${decoded['author_initial']}';
      final String? viewerReaction =
          decoded['viewer_reaction'] is String ? decoded['viewer_reaction'] as String : null;

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PostDetailScreen(
            postId: postId,
            apiBaseUrl: _shellApiBaseUrl,
            author: author.isEmpty ? 'Rider' : author,
            problem: problem.isEmpty ? 'Post detail' : problem,
            city: city,
            company: company,
            tags: tags,
            commentsCount: commentsCount,
            isAnonymous: isAnonymous,
            imageUrl: imageUrl,
            bodyFull: bodyFull,
            authorAvatarUrl: authorAvatarUrl,
            authorInitial: authorInitial,
            likesCount: likesCount,
            dislikesCount: dislikesCount,
            viewerReaction: viewerReaction,
          ),
        ),
      );
    } catch (_) {}
  }

  String _formatNotificationTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final DateTime local = dt.toLocal();
    final Duration diff = DateTime.now().difference(local);
    if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _openNotificationsSheet() async {
    await _checkNotifications();
    if (!mounted) return;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                          ),
                        ),
                        child: const Icon(Icons.notifications_rounded, color: Color(0xFF0B1F3A), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (_unreadNotifications > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark ? const Color(0x335B6B88) : const Color(0x332563EB),
                            ),
                          ),
                          child: Text(
                            'Unread $_unreadNotifications',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _notifications.isEmpty
                      ? Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          itemBuilder: (context, index) {
                            final Map<String, dynamic> row = _notifications[index];
                            final int id = int.tryParse('${row['id'] ?? 0}') ?? 0;
                            final String source = ('${row['source'] ?? 'broadcast'}').trim().toLowerCase();
                            final bool isRead = row['is_read'] == true;
                            final String title = ('${row['title'] ?? ''}').trim();
                            final String body = ('${row['body'] ?? ''}').trim();
                            final int postId = int.tryParse('${row['post_id'] ?? 0}') ?? 0;
                            final String timeText = _formatNotificationTime('${row['created_at'] ?? ''}');
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await _markNotificationRead(id, source: source);
                                  if (!mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  await _checkNotifications();
                                  if (postId > 0) {
                                    await _openPostDetailFromNotification(postId);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isRead
                                        ? (isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF))
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF5D8)),
                                    border: Border.all(
                                      color: isDark ? const Color(0x335B6B88) : const Color(0x33F4B400),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x100F172A),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isRead
                                              ? (isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC))
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFFFE9A8)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          postId > 0 ? Icons.forum_rounded : Icons.notifications_active_rounded,
                                          size: 18,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title.isEmpty ? 'Notification' : title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  timeText,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (body.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                body,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!isRead)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8, top: 6),
                                          child: Icon(
                                            Icons.brightness_1_rounded,
                                            size: 9,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 9),
                          itemCount: _notifications.length,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectTab(int index) async {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool compact,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_selectTab(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 4),
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 7, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.42) : Colors.transparent),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x332563EB),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 3,
                width: isSelected ? (compact ? 20 : 26) : 0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: compact ? 4 : 5),
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: isSelected ? 1.08 : 1,
                child: Icon(
                  icon,
                  size: compact ? 21 : 23,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0B1F3A))
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              SizedBox(
                height: compact ? 13 : 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0B1F3A))
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HamburgerGlyph extends StatelessWidget {
  const _HamburgerGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(width: 6, height: 2),
          _bar(width: 16, height: 2),
          _bar(width: 12, height: 2),
        ],
      ),
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({
    super.key,
    this.initialCity = '',
    required this.accessToken,
    this.languageCode = 'en',
    required this.onOpenCreatePost,
    required this.onOpenRefer,
  });

  /// Prefills city filter when it matches API/meta options.
  final String initialCity;
  final String accessToken;
  final String languageCode;
  final VoidCallback onOpenCreatePost;
  final VoidCallback onOpenRefer;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const String _apiAccessKey = ApiConfig.apiAccessKey;
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<String> _cityOptions = ['All', 'Delhi', 'Noida', 'Gurgaon'];
  List<String> _companyOptions = ['All companies', 'Blinkit', 'Zepto', 'Swiggy', 'Other'];
  List<String> _issueTypeOptions = ['All types', 'Payment', 'Safety', 'Account', 'Route'];

  late String _selectedCity;
  late String _selectedCompany;
  late String _selectedIssueType;

  final List<Map<String, dynamic>> _postRows = [];
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _loadError;
  bool _walletBannerLoading = true;
  int _walletBannerBalance = 0;
  String _walletBannerCode = '';

  String get _apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    final hint = widget.initialCity.trim();
    _selectedCity = hint.isNotEmpty && _cityOptions.contains(hint) ? hint : 'All';
    _selectedCompany = 'All companies';
    _selectedIssueType = 'All types';
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchDebounced);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapFeed());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchDebounced);
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingInitial || _loadingMore || !_hasMore || _loadError != null) return;
    final ScrollPosition pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      _fetchPage(reset: false);
    }
  }

  void _onSearchDebounced() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _fetchPage(reset: true);
    });
  }

  Future<void> _bootstrapFeed() async {
    unawaited(_loadWalletBanner());
    await _loadFilterOptionsFromMeta();
    if (!mounted) return;
    final hint = widget.initialCity.trim();
    if (hint.isNotEmpty && _cityOptions.contains(hint)) {
      setState(() => _selectedCity = hint);
    }
    await _fetchPage(reset: true);
  }

  Future<void> _loadWalletBanner() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() => _walletBannerLoading = false);
      return;
    }

    try {
      final Map<String, String> headers = <String, String>{
        'X-API-Key': _apiAccessKey,
        'Authorization': 'Bearer $token',
      };

      final Uri walletUri = Uri.parse('$_apiBaseUrl/api/v1/wallet/me');
      final Uri referralUri = Uri.parse('$_apiBaseUrl/api/v1/referral/me');

      final List<http.Response> responses = await Future.wait<http.Response>([
        http.get(walletUri, headers: headers),
        http.get(referralUri, headers: headers),
      ]);
      if (!mounted) return;

      int nextBalance = 0;
      String nextCode = '';

      final http.Response walletRes = responses[0];
      if (walletRes.statusCode == 200) {
        final dynamic walletDecoded = jsonDecode(walletRes.body);
        if (walletDecoded is Map<String, dynamic>) {
          final dynamic walletRaw = walletDecoded['wallet'];
          if (walletRaw is Map<String, dynamic>) {
            nextBalance = walletRaw['balance_credits'] is int
                ? walletRaw['balance_credits'] as int
                : int.tryParse('${walletRaw['balance_credits']}') ?? 0;
          }
        }
      }

      final http.Response referralRes = responses[1];
      if (referralRes.statusCode == 200) {
        final dynamic referralDecoded = jsonDecode(referralRes.body);
        if (referralDecoded is Map<String, dynamic>) {
          nextCode = ('${referralDecoded['referral_code'] ?? ''}').trim().toUpperCase();
        }
      }

      setState(() {
        _walletBannerBalance = nextBalance;
        _walletBannerCode = nextCode;
        _walletBannerLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletBannerLoading = false);
    }
  }

  Future<void> _copyReferralCode() async {
    final String code = _walletBannerCode.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code not available right now.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Referral code copied: $code')),
    );
  }

  Future<void> _loadFilterOptionsFromMeta() async {
    try {
      final Uri uri = Uri.parse('$_apiBaseUrl/api/v1/posts/meta');
      final http.Response res = await http.get(
        uri,
        headers: <String, String>{'X-API-Key': _apiAccessKey},
      );
      if (res.statusCode != 200 || !mounted) return;
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;

      List<String> labels(dynamic key) {
        final raw = decoded[key];
        if (raw is! List<dynamic>) return [];
        final List<String> out = [];
        for (final dynamic item in raw) {
          if (item is Map && item['label'] is String) {
            final String s = (item['label'] as String).trim();
            if (s.isNotEmpty) out.add(s);
          }
        }
        return out;
      }

      final cities = labels('cities');
      final companies = labels('companies');
      final issueTypes = labels('issue_types');
      if (cities.isEmpty || companies.isEmpty) return;

      setState(() {
        _cityOptions = ['All', ...cities];
        _companyOptions = ['All companies', ...companies];
        if (issueTypes.isNotEmpty) {
          _issueTypeOptions = ['All types', ...issueTypes];
        }
        if (!_cityOptions.contains(_selectedCity)) {
          _selectedCity = 'All';
        }
        if (!_companyOptions.contains(_selectedCompany)) {
          _selectedCompany = 'All companies';
        }
        if (!_issueTypeOptions.contains(_selectedIssueType)) {
          _selectedIssueType = 'All types';
        }
      });
    } catch (_) {
      // Keep hardcoded filter lists.
    }
  }

  /// Aligns with backend: strip leading `#` so `#Account` matches `[Account]` posts.
  static String _normalizedSearchQuery(String raw) {
    var t = raw.trim();
    while (t.startsWith('#')) {
      t = t.length > 1 ? t.substring(1).trim() : '';
    }
    return t;
  }

  static String _formatFeedTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Recently';
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final Duration diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 50) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 8) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _feedAuthorInitial(dynamic raw) {
    if (raw is! String) return '?';
    for (final int codeUnit in raw.trim().runes) {
      final String ch = String.fromCharCode(codeUnit);
      if (RegExp(r'[0-9A-Za-z]').hasMatch(ch)) {
        return ch.toUpperCase();
      }
    }
    return '?';
  }

  static int _feedInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  static int _feedPostId(dynamic v) {
    return _feedInt(v, -1);
  }

  static String? _feedViewerReaction(dynamic v) {
    if (v is String && (v == 'like' || v == 'dislike')) {
      return v;
    }
    return null;
  }

  void _patchPostReaction(int postId, int likes, int dislikes, String? viewer) {
    setState(() {
      for (final Map<String, dynamic> row in _postRows) {
        if (_feedPostId(row['id']) == postId) {
          row['likes_count'] = likes;
          row['dislikes_count'] = dislikes;
          row['viewer_reaction'] = viewer;
          break;
        }
      }
    });
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (_loadingMore && !reset) return;
    if (!reset && (!_hasMore || _loadingInitial)) return;

    if (reset) {
      setState(() {
        _loadingInitial = true;
        _loadError = null;
        _postRows.clear();
        _hasMore = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final int offset = reset ? 0 : _postRows.length;
    final Map<String, String> qp = <String, String>{
      'limit': '$_pageSize',
      'offset': '$offset',
    };
    if (_selectedCity != 'All' && _selectedCity.trim().isNotEmpty) {
      qp['city'] = _selectedCity.trim();
    }
    if (_selectedCompany != 'All companies' && _selectedCompany.trim().isNotEmpty) {
      qp['company'] = _selectedCompany.trim();
    }
    if (_selectedIssueType != 'All types' && _selectedIssueType.trim().isNotEmpty) {
      qp['issue_type'] = _selectedIssueType.trim();
    }
    final String q = _normalizedSearchQuery(_searchController.text);
    if (q.isNotEmpty) {
      qp['search'] = q;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String bearer = (prefs.getString('session_access_token') ?? '').trim();
      final Map<String, String> headers = <String, String>{
        'X-API-Key': _apiAccessKey,
        'Content-Type': 'application/json',
      };
      if (bearer.isNotEmpty) {
        headers['Authorization'] = 'Bearer $bearer';
      }

      final Uri uri = Uri.parse('$_apiBaseUrl/api/v1/posts').replace(queryParameters: qp);
      final http.Response response = await http.get(
        uri,
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _loadError = 'Feed load nahi hua (${response.statusCode}).';
          _loadingInitial = false;
          _loadingMore = false;
        });
        return;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _loadError = 'Invalid server response.';
          _loadingInitial = false;
          _loadingMore = false;
        });
        return;
      }

      final int total = (decoded['total'] is int) ? decoded['total'] as int : int.tryParse('${decoded['total']}') ?? 0;
      final List<dynamic> rawItems = decoded['items'] as List<dynamic>? ?? const [];

      final List<Map<String, dynamic>> next = [];
      for (final dynamic row in rawItems) {
        if (row is Map<String, dynamic>) {
          next.add(row);
        }
      }

      setState(() {
        _postRows.addAll(next);
        _hasMore = _postRows.length < total;
        _loadingInitial = false;
        _loadingMore = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Network error: $e';
        _loadingInitial = false;
        _loadingMore = false;
      });
    }
  }

  void _onCityChanged(String value) {
    setState(() => _selectedCity = value);
    _fetchPage(reset: true);
  }

  void _onCompanyChanged(String value) {
    setState(() => _selectedCompany = value);
    _fetchPage(reset: true);
  }

  void _onIssueTypeChanged(String value) {
    setState(() => _selectedIssueType = value);
    _fetchPage(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedCity = 'All';
      _selectedCompany = 'All companies';
      _selectedIssueType = 'All types';
      _searchController.clear();
    });
    _fetchPage(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isHindi = widget.languageCode.trim().toLowerCase() == 'hi';
    final List<Widget> children = <Widget>[
      _CommunityOverviewCard(isHindi: isHindi),
      const SizedBox(height: 12),
      _WalletReferralBanner(
        loading: _walletBannerLoading,
        balanceCredits: _walletBannerBalance,
        referralCode: _walletBannerCode,
        onOpenRefer: widget.onOpenRefer,
        onCopyReferral: _copyReferralCode,
      ),
      const SizedBox(height: 12),
      _CreatePostEntryCard(
        isHindi: isHindi,
        onOpenCreatePost: widget.onOpenCreatePost,
      ),
      const SizedBox(height: 14),
      _CommunityFeedFilters(
        searchController: _searchController,
        cityOptions: _cityOptions,
        companyOptions: _companyOptions,
        issueTypeOptions: _issueTypeOptions,
        selectedCity: _selectedCity,
        selectedCompany: _selectedCompany,
        selectedIssueType: _selectedIssueType,
        onCityChanged: _onCityChanged,
        onCompanyChanged: _onCompanyChanged,
        onIssueTypeChanged: _onIssueTypeChanged,
        onClearFilters: _clearFilters,
      ),
      const SizedBox(height: 12),
    ];

    if (_loadingInitial) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.all(Radius.circular(99)),
          ),
        ),
      );
    }

    if (_loadError != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _fetchPage(reset: true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$_loadError\nTap to retry.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < _postRows.length; i++) {
      final Map<String, dynamic> row = _postRows[i];
      final String author = '${row['author_display'] ?? 'Rider'}';
      final String body = '${row['body'] ?? ''}'.trim();
      final String bodyFull = '${row['body_full'] ?? row['body'] ?? ''}'.trim();
      final String city = '${row['city'] ?? ''}';
      final String company = '${row['company'] ?? ''}';
      final bool anon = row['is_anonymous'] == true;
      final List<String> tags = <String>[];
      final dynamic t = row['tags'];
      if (t is List<dynamic>) {
        for (final dynamic x in t) {
          if (x is String && x.trim().isNotEmpty) tags.add(x.trim());
        }
      }
      if (tags.isEmpty) tags.add('Community');
      final String? imageUrl = row['image_url'] is String ? row['image_url'] as String : null;
      final int comments = row['comments_count'] is int ? row['comments_count'] as int : 0;
      final String timeLabel = _formatFeedTime(row['created_at'] is String ? row['created_at'] as String : null);
      final int postId = _feedPostId(row['id']);
      final int likesCount = _feedInt(row['likes_count']);
      final int dislikesCount = _feedInt(row['dislikes_count']);
      final String? viewerRx = _feedViewerReaction(row['viewer_reaction']);

      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: i == _postRows.length - 1 ? 0 : 12),
          child: _PremiumPostCard(
            postId: postId,
            likesCount: likesCount,
            dislikesCount: dislikesCount,
            viewerReaction: viewerRx,
            apiBaseUrl: _apiBaseUrl,
            onReactionCountsUpdated: (likes, dislikes, viewer) =>
                _patchPostReaction(postId, likes, dislikes, viewer),
            author: author,
            problem: body.isEmpty ? bodyFull : body,
            bodyFull: bodyFull.isNotEmpty ? bodyFull : null,
            commentsCount: comments,
            isAnonymous: anon,
            city: city,
            company: company,
            tags: tags,
            imageUrl: imageUrl,
            timeLabel: timeLabel,
            authorAvatarUrl: anon
                ? null
                : (row['author_avatar_url'] is String ? row['author_avatar_url'] as String : null),
            authorInitial: anon
                ? '?'
                : _feedAuthorInitial(row['author_initial']),
          ),
        ),
      );
    }

    if (!_loadingInitial && _loadError == null && _postRows.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
          child: Text(
            'Abhi koi post nahi dikhega â€” pehla post tum banao ya filters clear karke dekho.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    if (_loadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    children.add(const SizedBox(height: 88));

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      children: children,
    );
  }
}

class _CommunityFeedFilters extends StatelessWidget {
  const _CommunityFeedFilters({
    required this.searchController,
    required this.cityOptions,
    required this.companyOptions,
    required this.issueTypeOptions,
    required this.selectedCity,
    required this.selectedCompany,
    required this.selectedIssueType,
    required this.onCityChanged,
    required this.onCompanyChanged,
    required this.onIssueTypeChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final List<String> cityOptions;
  final List<String> companyOptions;
  final List<String> issueTypeOptions;
  final String selectedCity;
  final String selectedCompany;
  final String selectedIssueType;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onCompanyChanged;
  final ValueChanged<String> onIssueTypeChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String safeCity = cityOptions.contains(selectedCity) ? selectedCity : cityOptions.first;
    final String safeCompany =
        companyOptions.contains(selectedCompany) ? selectedCompany : companyOptions.first;
    final String safeIssue =
        issueTypeOptions.contains(selectedIssueType) ? selectedIssueType : issueTypeOptions.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? null : const Color(0xFFFFFFFF),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xEE1F2937), Color(0xE6141F2F)],
              )
            : null,
        border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x33F4B400)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
                      const SizedBox(width: 6),
                      Text(
                        'Smart filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF0B1F3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: onClearFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear filters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x44F4B400)),
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0B1F3A)),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search text, #tag, city, company...',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84).withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterDropdownChip(
                icon: Icons.location_city_rounded,
                value: safeCity,
                options: cityOptions,
                onChanged: onCityChanged,
              ),
              _FilterDropdownChip(
                icon: Icons.business_center_rounded,
                value: safeCompany,
                options: companyOptions,
                onChanged: onCompanyChanged,
              ),
              _FilterDropdownChip(
                icon: Icons.label_outline_rounded,
                value: safeIssue,
                options: issueTypeOptions,
                onChanged: onIssueTypeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityOverviewCard extends StatelessWidget {
  const _CommunityOverviewCard({required this.isHindi});

  final bool isHindi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1751222177131-90948c33243f?auto=format&fit=crop&fm=jpg&q=80&w=1600',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xCC0B1F3A),
                    const Color(0x991D4ED8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isHindi ? 'राइडर कम्युनिटी' : 'Rider Community',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHindi
                        ? 'डिलीवरी राइडर्स के साथ पूछें, मदद करें और साथ में आगे बढ़ें।'
                        : 'Ask, help and grow together with delivery riders.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
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
}

class _WalletReferralBanner extends StatelessWidget {
  const _WalletReferralBanner({
    required this.loading,
    required this.balanceCredits,
    required this.referralCode,
    required this.onOpenRefer,
    required this.onCopyReferral,
  });

  final bool loading;
  final int balanceCredits;
  final String referralCode;
  final VoidCallback onOpenRefer;
  final VoidCallback onCopyReferral;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme alignment: Yellow/Gold/Amber color palette
    final Color primaryYellow = const Color(0xFFF4B400); // Main Theme Yellow
    final Color deepAmber = const Color(0xFFB45309);    // Accent Amber
    
    final Color cardBorder = isDark ? const Color(0x44F4B400) : const Color(0x33B45309);
    final Color cardBackground1 = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFDF5);
    final Color cardBackground2 = isDark ? const Color(0xFF0F172A) : const Color(0xFFFFF8E7);
    
    final Color textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0B1F3A);
    final Color subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardBackground1, cardBackground2],
        ),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x11B45309),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative subtle background shimmer or light circle for creative flair
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryYellow.withValues(alpha: isDark ? 0.06 : 0.08),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: deepAmber.withValues(alpha: isDark ? 0.04 : 0.06),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Chip, Contactless Wave, and Rider Gold Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Custom built card SIM chip
                          Container(
                            width: 38,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: const Color(0xFF78350F), width: 1),
                            ),
                            child: Stack(
                              children: [
                                // Chip lines
                                Center(
                                  child: Container(
                                    width: 18,
                                    height: 1,
                                    color: const Color(0xFF78350F).withValues(alpha: 0.5),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 1,
                                    height: 14,
                                    color: const Color(0xFF78350F).withValues(alpha: 0.5),
                                    margin: const EdgeInsets.only(left: 12),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: 1,
                                    height: 14,
                                    color: const Color(0xFF78350F).withValues(alpha: 0.5),
                                    margin: const EdgeInsets.only(right: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Wireless Contactless Sign
                          Transform.rotate(
                            angle: 1.5708, // Rotate 90 degrees
                            child: Icon(
                              Icons.wifi_rounded,
                              size: 16,
                              color: isDark ? primaryYellow.withValues(alpha: 0.6) : deepAmber.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      // Rider Gold / VIP club badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryYellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryYellow.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 14,
                              color: isDark ? primaryYellow : deepAmber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RIDER CLUB',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: isDark ? primaryYellow : deepAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Middle Section: Balance Credits
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Balance:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹$balanceCredits',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: isDark ? primaryYellow : textColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'credits',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Bottom Section: Embossed Referral Code Card-Number look & Copy/Refer action
                    Row(
                      children: [
                        // Referral Code field (embossed credit card spacing)
                        Expanded(
                          child: InkWell(
                            onTap: onCopyReferral,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBF1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFFDE68A),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.key_rounded,
                                    size: 14,
                                    color: isDark ? primaryYellow : deepAmber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      referralCode.isEmpty ? 'Code loading...' : referralCode,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        color: referralCode.isEmpty ? subtextColor : textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: isDark ? primaryYellow : deepAmber,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 10),
                        
                        // Action buttons
                        ElevatedButton.icon(
                          onPressed: onOpenRefer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryYellow,
                            foregroundColor: const Color(0xFF0B1F3A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 14),
                          label: const Text(
                            'Refer Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePostEntryCard extends StatelessWidget {
  const _CreatePostEntryCard({
    required this.isHindi,
    required this.onOpenCreatePost,
  });

  final bool isHindi;
  final VoidCallback onOpenCreatePost;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryYellow = const Color(0xFFF4B400);
    final Color deepAmber = const Color(0xFFB45309);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenCreatePost,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0x335B6B88) : primaryYellow.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Glowing circular container for write icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryYellow.withValues(alpha: 0.2),
                      primaryYellow.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: primaryYellow.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: isDark ? primaryYellow : deepAmber,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isHindi ? 'समस्या शेयर करें' : 'Share your issue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0B1F3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi 
                          ? 'अन्य डिलीवरी राइडर्स से राय लें...'
                          : 'Ask and get help from fellow riders...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Beautiful minimal plus badge / arrow indicating clickability
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryYellow,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryYellow.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF0B1F3A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHindi ? 'लिखें' : 'Post',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B1F3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdownChip extends StatelessWidget {
  const _FilterDropdownChip({
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF111827)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x44F4B400), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
          const SizedBox(width: 5),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0B1F3A),
              ),
              dropdownColor: isDark ? const Color(0xFF1F2937) : null,
              items: options
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (newValue) {
                if (newValue != null) onChanged(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicUpdateCard extends StatelessWidget {
  const _DynamicUpdateCard();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0x33F59E0B) : const Color(0x1FF97316)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFFFE8C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform update',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE5E7EB) : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Today 7 PM: payment issue support live session.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFCBD5E1) : null,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _PremiumPostCard extends StatefulWidget {
  const _PremiumPostCard({
    required this.postId,
    required this.likesCount,
    required this.dislikesCount,
    this.viewerReaction,
    required this.apiBaseUrl,
    required this.onReactionCountsUpdated,
    required this.author,
    required this.problem,
    required this.commentsCount,
    required this.isAnonymous,
    required this.city,
    required this.company,
    required this.tags,
    this.imageUrl,
    this.bodyFull,
    this.timeLabel = 'Recently',
    this.authorAvatarUrl,
    this.authorInitial = '?',
  });

  final int postId;
  final int likesCount;
  final int dislikesCount;
  final String? viewerReaction;
  final String apiBaseUrl;
  final void Function(int likes, int dislikes, String? viewer) onReactionCountsUpdated;

  final String author;
  final String problem;
  /// Full stored body (with `[Type]` line); detail screen prefers this when set.
  final String? bodyFull;
  final int commentsCount;
  final bool isAnonymous;
  final String city;
  final String company;
  final List<String> tags;
  final String? imageUrl;
  final String timeLabel;
  /// Shown for non-anonymous posts when [authorAvatarUrl] is null or fails to load.
  final String authorInitial;
  final String? authorAvatarUrl;

  @override
  State<_PremiumPostCard> createState() => _PremiumPostCardState();
}

class _PremiumPostCardState extends State<_PremiumPostCard> {
  static const String _reactionApiKey = ApiConfig.apiAccessKey;
  static const int _feedPreviewMaxChars = 220;

  late int _likes;
  late int _dislikes;
  String? _viewer;
  bool _reactionBusy = false;
  String? _busySide;

  bool _translated = false;
  bool _isTranslating = false;
  String? _translatedText;
  final GoogleTranslator _translator = GoogleTranslator();

  @override
  void initState() {
    super.initState();
    _syncReactionsFromWidget();
  }

  void _syncReactionsFromWidget() {
    _likes = widget.likesCount;
    _dislikes = widget.dislikesCount;
    _viewer = widget.viewerReaction;
  }

  @override
  void didUpdateWidget(covariant _PremiumPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_reactionBusy &&
        (oldWidget.likesCount != widget.likesCount ||
            oldWidget.dislikesCount != widget.dislikesCount ||
            oldWidget.viewerReaction != widget.viewerReaction)) {
      _syncReactionsFromWidget();
    }
  }

  Future<void> _submitReactionTap(String side) async {
    if (widget.postId < 0 || _reactionBusy) return;

    final String kind;
    if (side == 'like') {
      kind = _viewer == 'like' ? 'none' : 'like';
    } else {
      kind = _viewer == 'dislike' ? 'none' : 'dislike';
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = (prefs.getString('session_access_token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle login karo â€” phir like/dislike kar sakte ho.')),
      );
      return;
    }

    setState(() {
      _reactionBusy = true;
      _busySide = side;
    });

    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/posts/${widget.postId}/reaction');
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'X-API-Key': _reactionApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{'kind': kind}),
      );

      if (!mounted) return;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reaction save nahi hua (${res.statusCode}).')),
        );
        return;
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;

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
      widget.onReactionCountsUpdated(likes, dislikes, viewer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network: $e')));
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
          color: selected ? Colors.white : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
        ),
      );
    }
    return Icon(
      selected ? filled : outlined,
      size: 14,
      color: selected ? Colors.white : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
    );
  }

  String _cleanAuthorDisplay(String rawAuthor, String city) {
    String author = rawAuthor.trim().replaceAll('â€¢', '•').replaceAll(RegExp(r'\s+'), ' ');
    final String cleanCity = city.trim();
    if (cleanCity.isNotEmpty) {
      author = author
          .replaceFirst(
            RegExp(r'\s*(,|•|-|\|)\s*' + RegExp.escape(cleanCity) + r'\s*$', caseSensitive: false),
            '',
          )
          .trim();
    }
    return author.isEmpty ? 'Rider' : author;
  }

  String _postMetaText() {
    final List<String> parts = <String>[
      widget.company.trim(),
      widget.city.trim(),
    ].where((String value) => value.isNotEmpty).toList();
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> avatarColors = widget.isAnonymous
        ? const [Color(0xFF64748B), Color(0xFF334155)]
        : const [Color(0xFF0B1F3A), Color(0xFFFFC928)];
    final String visibleProblem = _translated ? (_translatedText ?? widget.problem) : widget.problem;
    final bool hasLongContent = _isLongPostText(visibleProblem);
    final String displayAuthor = _cleanAuthorDisplay(widget.author, widget.city);
    final String metaText = _postMetaText();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _openPostDetail,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x26FFB300)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Author row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAuthorAvatar(avatarColors, isDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayAuthor,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF102A56),
                            ),
                          ),
                          if (metaText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                metaText,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF0B1F3A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // Problem text
                Text(
                  visibleProblem,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 16,
                    color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasLongContent)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _openPostDetail,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(top: 6, bottom: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Show more',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Color(0xFF93C5FD) : Color(0xFF0B1F3A),
                        ),
                      ),
                    ),
                  ),

                if (widget.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '# $tag',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1B2A44),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x22FFB300)),
                const SizedBox(height: 12),

                // Responsive action row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PostActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: widget.commentsCount == 1
                          ? '1 reply'
                          : '${widget.commentsCount} replies',
                      color: const Color(0xFF0B1F3A),
                      onTap: _openPostDetail,
                    ),
                    GestureDetector(
                      onTap: _reactionBusy ? null : () => _submitReactionTap('like'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _viewer == 'like'
                              ? const Color(0xFF0B1F3A)
                              : (isDark ? const Color(0xFF111827) : const Color(0xFFF0F5FF)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _viewer == 'like'
                                ? const Color(0xFF0B1F3A)
                                : (isDark ? const Color(0x335B6B88) : const Color(0x3394A3B8)),
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
                                    : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _reactionBusy ? null : () => _submitReactionTap('dislike'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _viewer == 'dislike'
                              ? const Color(0xFFDC2626)
                              : (isDark ? const Color(0xFF111827) : const Color(0xFFF0F5FF)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _viewer == 'dislike'
                                ? const Color(0xFFDC2626)
                                : (isDark ? const Color(0x335B6B88) : const Color(0x3394A3B8)),
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
                                    : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF0B1F3A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _PostActionButton(
                      icon: Icons.translate_rounded,
                      label: _isTranslating
                          ? 'Translating...'
                          : (_translated ? 'Original' : 'Translate'),
                      color: const Color(0xFF0F766E),
                      onTap: _isTranslating ? () {} : _toggleTranslation,
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
    );
  }

  Widget _buildAuthorAvatar(List<Color> avatarColors, bool isDark) {
    if (widget.isAnonymous) {
      return _avatarShell(
        avatarColors: avatarColors,
        child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 22),
      );
    }
    final String? url = widget.authorAvatarUrl?.trim();
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
            errorBuilder: (context, error, stackTrace) => _letterAvatar(avatarColors),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 46,
                height: 46,
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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

  Widget _avatarShell({required List<Color> avatarColors, required Widget child}) {
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
    final String raw = widget.authorInitial.trim();
    final String letter = raw.isNotEmpty ? raw.substring(0, 1).toUpperCase() : '?';
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

  void _openPostDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailScreen(
          postId: widget.postId,
          apiBaseUrl: widget.apiBaseUrl,
          author: _cleanAuthorDisplay(widget.author, widget.city),
          problem: widget.problem,
          bodyFull: widget.bodyFull,
          city: widget.city,
          company: widget.company,
          tags: widget.tags,
          commentsCount: widget.commentsCount,
          isAnonymous: widget.isAnonymous,
          imageUrl: widget.imageUrl,
          authorAvatarUrl: widget.authorAvatarUrl,
          authorInitial: widget.authorInitial,
          likesCount: _likes,
          dislikesCount: _dislikes,
          viewerReaction: _viewer,
        ),
      ),
    );
  }

  Future<void> _toggleTranslation() async {
    if (_translated) {
      setState(() {
        _translated = false;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final String source = _detectSupportedLanguage(widget.problem);
      final String target = source == 'hi' ? 'en' : 'hi';
      final Translation result = await _translator.translate(
        widget.problem,
        from: source,
        to: target,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _translatedText = result.text;
        _translated = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  String _detectSupportedLanguage(String text) {
    final RegExp devanagariRegex = RegExp(r'[\u0900-\u097F]');
    return devanagariRegex.hasMatch(text) ? 'hi' : 'en';
  }

  bool _isLongPostText(String text) {
    final String normalized = text.trim();
    if (normalized.length > _feedPreviewMaxChars) return true;
    final int newlines = '\n'.allMatches(normalized).length;
    return newlines >= 3;
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.07);
    final Color textColor = isDark ? Colors.white : color;
    final Color borderColor = isDark ? color.withValues(alpha: 0.35) : color.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
    );
  }
}

class RiderOnboardingDetailsScreen extends StatefulWidget {
  const RiderOnboardingDetailsScreen({
    super.key,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
    required this.onCompleted,
  });

  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;
  final VoidCallback onCompleted;

  @override
  State<RiderOnboardingDetailsScreen> createState() => _RiderOnboardingDetailsScreenState();
}

class _RiderOnboardingDetailsScreenState extends State<RiderOnboardingDetailsScreen> {
  static const List<String> _fallbackCompanies = <String>[
    'Blinkit',
    'Zepto',
    'Swiggy',
    'Zomato',
    'Other',
  ];
  static const Map<String, List<String>> _companyCategorySeeds = <String, List<String>>{
    'Food Delivery': <String>['Zomato', 'Swiggy', 'FNP', 'Other'],
    'Bike Taxi': <String>['Ola', 'Uber', 'Rapido'],
    'Ecommerce': <String>['Zepto', 'Blinkit', 'BigBasket', 'Amazon', 'Flipkart'],
    'Parcel': <String>['Porter', 'Borzo', 'Delhivery', 'Dunzo'],
  };
  static const String _apiAccessKey = ApiConfig.apiAccessKey;

  final TextEditingController _riderIdController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _otherCompanyController = TextEditingController();
  final TextEditingController _evModelController = TextEditingController();
  final TextEditingController _evNumberController = TextEditingController();
  final TextEditingController _purchaseYearController = TextEditingController();

  List<String> _companies = List<String>.from(_fallbackCompanies);
  String _company = _fallbackCompanies.first;
  String _vehicleType = 'ev_scooter';
  bool _hasEv = false;
  bool _loading = true;
  bool _saving = false;
  bool _detailsLocked = false;
  String _selectedCategory = 'Food Delivery';
  List<Map<String, dynamic>> _companyMetaList = <Map<String, dynamic>>[];
  bool _formVisible = false;

  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCompaniesFromMeta();
  }

  @override
  void dispose() {
    _riderIdController.dispose();
    _cityController.dispose();
    _otherCompanyController.dispose();
    _evModelController.dispose();
    _evNumberController.dispose();
    _purchaseYearController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String company = (prefs.getString('onboarding_company') ?? _fallbackCompanies.first).trim();
    setState(() {
      _company = _companies.contains(company) ? company : _companies.first;
      _selectedCategory = _categoryForCompany(_company);
      _riderIdController.text = (prefs.getString('onboarding_rider_id') ?? '').trim();
      _cityController.text = (prefs.getString('onboarding_city') ?? '').trim();
      _otherCompanyController.text = (prefs.getString('onboarding_other_company') ?? '').trim();
      _hasEv = prefs.getBool('onboarding_has_ev') ?? false;
      _evModelController.text = (prefs.getString('onboarding_ev_model') ?? '').trim();
      _evNumberController.text = (prefs.getString('onboarding_ev_number') ?? '').trim();
      _purchaseYearController.text = (prefs.getString('onboarding_purchase_year') ?? '').trim();
      final String savedVehicleType =
          (prefs.getString('onboarding_vehicle_type') ?? 'ev_scooter').trim();
      if (savedVehicleType.startsWith('ev_')) {
        _vehicleType = 'ev_scooter';
      } else if (savedVehicleType == 'bike' ||
          savedVehicleType == 'scooter' ||
          savedVehicleType == 'other') {
        _vehicleType = 'bike';
      } else {
        _vehicleType = 'ev_scooter';
      }
      _hasEv = _vehicleType.startsWith('ev_');
      _detailsLocked = prefs.getBool('onboarding_details_locked') ?? false;
      _loading = false;
      _formVisible = _detailsLocked ||
          _riderIdController.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _evNumberController.text.trim().isNotEmpty;
    });
    await _loadRemoteOnboarding();
  }

  Future<void> _loadRemoteOnboarding() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;

    try {
      String? riderCompany;
      String? riderId;
      String? city;
      final http.Response profileResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/auth/me'),
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (profileResponse.statusCode >= 200 && profileResponse.statusCode < 300) {
        final dynamic decoded = jsonDecode(profileResponse.body);
        if (decoded is Map<String, dynamic> && decoded['profile'] is Map<String, dynamic>) {
          final Map<String, dynamic> profile = decoded['profile'] as Map<String, dynamic>;
          riderCompany = ('${profile['rider_company'] ?? ''}').trim();
          riderId = ('${profile['rider_id'] ?? ''}').trim();
          city = ('${profile['city'] ?? ''}').trim();
        }
      }

      Map<String, dynamic>? vehicle;
      final http.Response vehicleResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/vehicle/me'),
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (vehicleResponse.statusCode >= 200 && vehicleResponse.statusCode < 300) {
        final dynamic decoded = jsonDecode(vehicleResponse.body);
        if (decoded is Map<String, dynamic> && decoded['vehicle'] is Map<String, dynamic>) {
          vehicle = decoded['vehicle'] as Map<String, dynamic>;
        }
      }

      if (!mounted) return;
      setState(() {
        if ((riderId ?? '').isNotEmpty) {
          _riderIdController.text = riderId!;
        }
        if ((city ?? '').isNotEmpty) {
          _cityController.text = city!;
        }
        if ((riderCompany ?? '').isNotEmpty) {
          final String company = riderCompany!;
          if (!_companies.contains(company)) {
            _companies = <String>[..._companies.where((String item) => item != 'Other'), company, 'Other'];
          }
          _company = company;
          _selectedCategory = _categoryForCompany(company);
        }
        if (vehicle != null) {
          _detailsLocked = true;
          _formVisible = true;
          final String type = ('${vehicle['vehicle_type'] ?? 'ev_scooter'}').trim();
          if (type.startsWith('ev_')) {
            _vehicleType = 'ev_scooter';
          } else if (type == 'bike' || type == 'scooter' || type == 'other') {
            _vehicleType = 'bike';
          } else {
            _vehicleType = 'ev_scooter';
          }
          _hasEv = _vehicleType.startsWith('ev_');
          _evModelController.text = ('${vehicle['model_name'] ?? ''}').trim();
          _evNumberController.text = ('${vehicle['registration_number'] ?? ''}').trim();
          _purchaseYearController.text = ('${vehicle['purchase_year'] ?? ''}').trim();
          final dynamic metadata = vehicle['metadata'];
          if (_riderIdController.text.trim().isEmpty && metadata is Map) {
            _riderIdController.text = ('${metadata['rider_id'] ?? ''}').trim();
          }
        }
      });
    } catch (_) {
      // Keep local onboarding details editable if remote lookup fails.
    }
  }

  static const List<String> _vehicleTypes = <String>[
    'ev_scooter',
    'bike',
  ];

  String _vehicleTypeLabel(String type) {
    switch (type) {
      case 'bike':
        return _tr('Petrol', 'पेट्रोल');
      case 'ev_scooter':
      default:
        return _tr('EV', 'ईवी');
    }
  }

  Future<void> _loadCompaniesFromMeta() async {
    try {
      final Uri uri = Uri.parse('${ApiConfig.apiBaseUrl}/api/v1/posts/meta');
      final http.Response res = await http.get(
        uri,
        headers: <String, String>{'X-API-Key': _apiAccessKey},
      );
      if (res.statusCode != 200 || !mounted) return;
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      final dynamic raw = decoded['companies'];
      if (raw is! List<dynamic>) return;

      final List<String> next = <String>[];
      final List<Map<String, dynamic>> metaList = <Map<String, dynamic>>[];
      for (final dynamic item in raw) {
        if (item is Map && item['label'] is String) {
          final String label = (item['label'] as String).trim();
          if (label.isNotEmpty) {
            next.add(label);
            metaList.add(Map<String, dynamic>.from(item));
          }
        }
      }
      if (next.isEmpty) return;
      if (!next.contains('Other')) {
        next.add('Other');
      }
      if (_company.isNotEmpty && !next.contains(_company)) {
        next.insert(next.length - 1, _company);
      }
      if (!mounted) return;
      setState(() {
        _companies = next;
        _companyMetaList = metaList;
        if (!_companies.contains(_company)) {
          _company = _companies.first;
        }
        _selectedCategory = _categoryForCompany(_company);
      });
    } catch (_) {
      // Keep fallback companies.
    }
  }

  Future<void> _save() async {
    if (_detailsLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Onboarding details are already submitted and cannot be changed.',
              'ऑनबोर्डिंग जानकारी पहले ही सबमिट हो चुकी है और अब बदली नहीं जा सकती।',
            ),
          ),
        ),
      );
      return;
    }
    final String riderId = _riderIdController.text.trim();
    final String city = _cityController.text.trim();
    final String riderCompany =
        _company == 'Other' ? _otherCompanyController.text.trim() : _company.trim();
    final String vehicleModel = _evModelController.text.trim();
    final String registrationNumber = _evNumberController.text.trim();

    final List<String> missing = <String>[];
    if (riderCompany.isEmpty) missing.add('Company');
    if (riderId.isEmpty) missing.add('Rider ID');
    if (city.isEmpty) missing.add('City');
    if (_vehicleType.trim().isEmpty) missing.add('Vehicle type');
    if (registrationNumber.isEmpty) missing.add('Vehicle number');
    if (missing.isNotEmpty) {
      await _showRequiredInfoDialog(missing);
      return;
    }

    final bool confirmed = await _confirmPermanentSave();
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final String token = widget.accessToken.trim();
      if (token.isEmpty) {
        throw Exception('Missing access token.');
      }
      final int? purchaseYear = int.tryParse(_purchaseYearController.text.trim());
      final http.MultipartRequest profileRequest = http.MultipartRequest(
        'PATCH',
        Uri.parse('${widget.apiBaseUrl}/api/v1/auth/profile'),
      )
        ..headers.addAll(<String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer $token',
        })
        ..fields['rider_id'] = riderId
        ..fields['rider_company'] = riderCompany
        ..fields['city'] = city;
      final http.StreamedResponse profileStream = await profileRequest.send();
      final String profileBody = await profileStream.stream.bytesToString();
      if (profileStream.statusCode < 200 || profileStream.statusCode >= 300) {
        String message = 'Could not save rider profile details.';
        try {
          final dynamic decoded = jsonDecode(profileBody);
          if (decoded is Map && decoded['detail'] != null) {
            message = '${decoded['detail']}';
          }
        } catch (_) {}
        throw Exception(message);
      }

      final http.Response response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/api/v1/vehicle/me'),
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'vehicle_type': _vehicleType,
          'company_name': riderCompany,
          'model_name': vehicleModel,
          'registration_number': registrationNumber,
          'chassis_number': '',
          'battery_number': '',
          'color': '',
          'purchase_year': purchaseYear,
          'is_active': true,
          'metadata': <String, dynamic>{
            'rider_id': riderId,
            'rider_company': riderCompany,
            'has_ev': _vehicleType.startsWith('ev_'),
            'onboarding_category': _categoryForCompany(riderCompany),
            'onboarding_partner': riderCompany,
          },
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Could not save vehicle details.';
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            message = '${decoded['detail']}';
          }
        } catch (_) {}
        throw Exception(message);
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding_company', _company);
      await prefs.setString('onboarding_category', _categoryForCompany(riderCompany));
      await prefs.setString('onboarding_rider_id', riderId);
      await prefs.setString('onboarding_city', city);
      await prefs.setString('onboarding_other_company', _otherCompanyController.text.trim());
      await prefs.setBool('onboarding_has_ev', _vehicleType.startsWith('ev_'));
      await prefs.setString('onboarding_vehicle_type', _vehicleType);
      await prefs.setString('onboarding_ev_model', vehicleModel);
      await prefs.setString('onboarding_ev_number', registrationNumber);
      await prefs.setString('onboarding_ev_range', '');
      await prefs.setString('onboarding_battery_number', '');
      await prefs.setString('onboarding_vehicle_color', '');
      await prefs.setString('onboarding_purchase_year', _purchaseYearController.text.trim());
      await prefs.setBool('onboarding_details_locked', true);
      if (!mounted) return;
      setState(() {
        _detailsLocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Onboarding and vehicle details saved.', 'ऑनबोर्डिंग और वाहन जानकारी सेव हो गई।'))),
      );
      widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _confirmPermanentSave() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_tr('Submit onboarding details?', 'ऑनबोर्डिंग जानकारी सबमिट करें?')),
          content: Text(
            _tr(
              'Your details will be locked to prevent accidental changes, but you can unlock and edit them anytime if your work information changes.',
              'आपकी जानकारी को गलती से बदलने से रोकने के लिए लॉक कर दिया जाएगा, लेकिन यदि आपका काम का विवरण बदलता है, तो आप इसे कभी भी अनलॉक और एडिट कर सकते हैं।',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_tr('Review again', 'फिर से देखें')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.lock_rounded),
              label: Text(_tr('Submit & lock', 'सबमिट और लॉक करें')),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showRequiredInfoDialog(List<String> missing) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Complete required details'),
          content: Text(
            'Submit karne se pehle ye information bharni zaroori hai:\n\n'
            '${missing.map((String item) => 'â€¢ $item').join('\n')}\n\n'
            'Please fill these details before submitting.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required bool isDark,
    IconData? icon,
    String? hint,
  }) {
    final Color border = isDark ? const Color(0x335B6B88) : const Color(0x33FFB300);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0B1F3A), width: 1.2),
      ),
    );
  }

  Color _parseHexColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.trim().isEmpty) return fallback;
    String hex = hexString.trim().replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final int? val = int.tryParse(hex, radix: 16);
      if (val != null) {
        return Color(val);
      }
    }
    return fallback;
  }

  Map<String, dynamic>? _getCompanyMeta(String company) {
    final String normalized = company.trim().toLowerCase();
    for (final dynamic item in _companyMetaList) {
      if (item is Map && item['label'] != null && item['label'].toString().trim().toLowerCase() == normalized) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  String _categoryForCompany(String company) {
    final String normalized = company.trim().toLowerCase();
    if (normalized.isEmpty) return _selectedCategory;
    final Map<String, dynamic>? meta = _getCompanyMeta(company);
    if (meta != null && meta['category'] is String && (meta['category'] as String).trim().isNotEmpty) {
      final String cat = (meta['category'] as String).trim();
      if (cat == 'Other Services') {
        return 'Food Delivery';
      }
      return cat;
    }
    for (final entry in _companyCategorySeeds.entries) {
      for (final String item in entry.value) {
        if (item.trim().toLowerCase() == normalized) {
          return entry.key;
        }
      }
    }
    return 'Food Delivery';
  }

  Map<String, List<String>> _categorizedCompanies() {
    final Map<String, List<String>> result = <String, List<String>>{};
    
    // 1. Initialize with static categories to preserve custom UI order
    for (final String category in _companyCategorySeeds.keys) {
      result[category] = <String>[];
    }
    
    // 2. Add dynamic categories found in metadata
    for (final Map<String, dynamic> item in _companyMetaList) {
      if (item['category'] is String) {
        final String cat = (item['category'] as String).trim();
        if (cat.isNotEmpty && cat != 'Other Services' && !result.containsKey(cat)) {
          result[cat] = <String>[];
        }
      }
    }

    // 3. Group companies
    for (final String company in _companies) {
      final String clean = company.trim();
      if (clean.isEmpty) continue;
      final String category = _categoryForCompany(clean);
      final List<String> bucket = result.putIfAbsent(category, () => <String>[]);
      if (!bucket.contains(clean)) bucket.add(clean);
    }

    // Remove empty categories to keep the UI clean
    final List<String> keys = result.keys.toList();
    for (final String key in keys) {
      if (result[key]!.isEmpty && key != _selectedCategory) {
        result.remove(key);
      }
    }

    result.forEach((_, List<String> bucket) {
      bucket.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
    return result;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Bike Taxi':
        return Icons.two_wheeler_rounded;
      case 'Ecommerce':
        return Icons.shopping_bag_outlined;
      case 'Parcel':
        return Icons.inventory_2_outlined;
      case 'Other Services':
        return Icons.widgets_outlined;
      case 'Food Delivery':
      default:
        return Icons.room_service_outlined;
    }
  }

  void _selectCompany(String company) {
    setState(() {
      _company = company;
      _selectedCategory = _categoryForCompany(company);
    });
  }

  Widget _buildCompanyLogo(String company, bool selected) {
    final Map<String, dynamic>? meta = _getCompanyMeta(company);
    final String? logoUrl = meta != null ? meta['logo_image_url'] as String? : null;

    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF0B1F3A) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildLocalCompanyLogo(company, selected);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        selected ? const Color(0xFF0B1F3A) : const Color(0xFF94A3B8),
                      ),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return _buildLocalCompanyLogo(company, selected);
  }

  Widget _buildLocalCompanyLogo(String company, bool selected) {
    final String option = company;
    final String clean = option.trim().toLowerCase();
    
    switch (clean) {
      case 'zomato':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFCB202D),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'z',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              fontFamily: 'serif',
            ),
          ),
        );
      case 'swiggy':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFFC8019),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'popeyes':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFF15A24),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'fnp':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF4A773C),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: Colors.white,
            size: 12,
          ),
        );
      case 'ola':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFD4E157),
              shape: BoxShape.circle,
            ),
          ),
        );
      case 'uber':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'Uber',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 6,
            ),
          ),
        );
      case 'rapido':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE000),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.motorcycle_rounded,
            color: Colors.black,
            size: 14,
          ),
        );
      case 'zepto':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF5E2B97),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'zepto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 5.5,
            ),
          ),
        );
      case 'blinkit':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFF7EC13),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.shopping_basket_rounded,
            color: Colors.black,
            size: 13,
          ),
        );
      case 'porter':
      case 'potter':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF421EAE),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        );
      default:
        return CircleAvatar(
          radius: 12,
          backgroundColor: selected
              ? const Color(0xFF0B1F3A)
              : const Color(0xFFE2E8F0),
          child: Text(
            option.isEmpty ? '?' : option.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0B1F3A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
    }
  }

  Map<String, dynamic> _getCategoryVisuals(String category) {
    final String clean = category.trim().toLowerCase();
    
    if (clean.contains('food') || clean.contains('delivery') || clean.contains('restaurant')) {
      return {
        'title': _tr('Food Delivery', 'फूड डिलीवरी'),
        'subtitle': _tr('Order from your favorite restaurants & get it delivered', 'अपने पसंदीदा रेस्तरां से ऑर्डर करें और डिलीवरी पाएं'),
        'iconBgColor': const Color(0xFFFFF2E6),
        'iconColor': const Color(0xFFFC6011),
        'iconData': Icons.room_service_outlined,
      };
    } else if (clean.contains('bike') || clean.contains('taxi') || clean.contains('texi') || clean.contains('moped')) {
      return {
        'title': _tr('Bike Taxi', 'बाइक टैक्सी'),
        'subtitle': _tr('Book a ride & travel to your destination', 'राइड बुक करें और अपने गंतव्य तक यात्रा करें'),
        'iconBgColor': const Color(0xFFE6F7F0),
        'iconColor': const Color(0xFF059669),
        'iconData': Icons.moped_rounded,
      };
    } else if (clean.contains('ecom') || clean.contains('grocer') || clean.contains('shop') || clean.contains('market')) {
      return {
        'title': _tr('Ecommerce', 'ई-कॉमर्स'),
        'subtitle': _tr('Get groceries & essentials delivered in minutes', 'मिनटों में ग्रोसरी और जरूरी सामान डिलीवरी पाएं'),
        'iconBgColor': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF8B5CF6),
        'iconData': Icons.shopping_bag_outlined,
      };
    } else if (clean.contains('parcel') || clean.contains('package') || clean.contains('box') || clean.contains('delivery') || clean.contains('porter') || clean.contains('potter')) {
      return {
        'title': _tr('Parcel', 'पार्सल'),
        'subtitle': _tr('Send packages & documents safely', 'पैकेज और दस्तावेज सुरक्षित रूप से भेजें'),
        'iconBgColor': const Color(0xFFE0F2FE),
        'iconColor': const Color(0xFF0284C7),
        'iconData': Icons.inventory_2_outlined,
      };
    } else {
      return {
        'title': category,
        'subtitle': _tr('Delivery and logistics services', 'डिलीवरी और लॉजिस्टिक्स सेवाएं'),
        'iconBgColor': const Color(0xFFF1F5F9),
        'iconColor': const Color(0xFF475569),
        'iconData': Icons.widgets_outlined,
      };
    }
  }

  Widget _buildCompanyRow(String companyName, bool isDark) {
    final bool selected = _company == companyName;
    final Map<String, dynamic>? meta = _getCompanyMeta(companyName);
    final Color brandColor = _parseHexColor(
      meta != null ? meta['brand_color'] as String? : null,
      const Color(0xFF0B1F3A),
    );

    return InkWell(
      onTap: _detailsLocked ? null : () {
        _selectCompany(companyName);
        setState(() {
          _formVisible = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: selected
              ? brandColor.withValues(alpha: isDark ? 0.12 : 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Left selection indicator pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              width: selected ? 3.5 : 0,
              height: selected ? 20 : 0,
              margin: EdgeInsets.only(right: selected ? 8 : 0),
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildCompanyLogo(companyName, selected),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                companyName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? (isDark ? Colors.white : brandColor)
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('check'),
                      size: 18,
                      color: isDark ? Colors.white : brandColor,
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      key: const ValueKey('chevron'),
                      size: 18,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String category,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required IconData iconData,
    required List<String> companies,
    required bool isDark,
  }) {
    if (companies.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x060F172A),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top accent gradient color bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.8),
                    iconColor,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? iconBgColor.withValues(alpha: 0.15) : iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: companies.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    height: 1,
                    thickness: 1,
                  ),
                  itemBuilder: (context, index) {
                    final String companyName = companies[index];
                    return _buildCompanyRow(companyName, isDark);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool compact = MediaQuery.of(context).size.width < 390;
    final bool hasOtherCompany = _company == 'Other';
    final Map<String, List<String>> categorized = _categorizedCompanies();

    final List<String> activeCategories = categorized.keys
        .where((String k) => categorized[k]!.isNotEmpty)
        .toList();

    // Sort to keep standard premium order
    activeCategories.sort((String a, String b) {
      int score(String cat) {
        final String c = cat.toLowerCase();
        if (c.contains('food')) return 0;
        if (c.contains('bike') || c.contains('texi') || c.contains('taxi')) return 1;
        if (c.contains('ecom')) return 2;
        if (c.contains('parcel')) return 3;
        return 4;
      }
      return score(a).compareTo(score(b));
    });

    final List<String> leftCategories = <String>[];
    final List<String> rightCategories = <String>[];
    for (int i = 0; i < activeCategories.length; i++) {
      if (i % 2 == 0) {
        leftCategories.add(activeCategories[i]);
      } else {
        rightCategories.add(activeCategories[i]);
      }
    }

    int completed = 0;
    completed += 1; // company chosen
    if (_riderIdController.text.trim().isNotEmpty) completed += 1;
    if (_cityController.text.trim().isNotEmpty) completed += 1;
    if (_evModelController.text.trim().isNotEmpty) completed += 1;
    if (_evNumberController.text.trim().isNotEmpty) {
      completed += 1;
    }
    final double progress = (completed / 5).clamp(0.0, 1.0);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1F2937), Color(0xFF0F172A)]
                    : const [Color(0xFF0B1F3A), Color(0xFFB45309)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr('Rider Onboarding', 'राइडर ऑनबोर्डिंग'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x180F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1.55,
              child: Image.asset(
                'assets/images/onboarding_rider_hero.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1F2937), Color(0xFF111827)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFF8E8)],
              ),
              border: Border.all(
                color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0B1F3A)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _formVisible 
                      ? _tr('Verification Details', 'सत्यापन विवरण') 
                      : _tr('Work Details', 'काम की जानकारी'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                  ),
                ),
                if (_detailsLocked) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFF3D1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tr('Details submitted. Editing is locked.', 'जानकारी सबमिट हो चुकी है। एडिट लॉक है।'),
                            style: TextStyle(
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: !_formVisible
                      ? Column(
                          key: const ValueKey('catalog_step'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr('Select your company', 'अपनी कंपनी चुनें'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // ── The beautiful 2-column catalog grid of categories ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: leftCategories.map((String cat) {
                                      final Map<String, dynamic> visuals = _getCategoryVisuals(cat);
                                      return _buildCategoryCard(
                                        category: cat,
                                        title: visuals['title'] as String,
                                        subtitle: visuals['subtitle'] as String,
                                        iconBgColor: visuals['iconBgColor'] as Color,
                                        iconColor: visuals['iconColor'] as Color,
                                        iconData: visuals['iconData'] as IconData,
                                        companies: categorized[cat] ?? <String>[],
                                        isDark: isDark,
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: rightCategories.map((String cat) {
                                      final Map<String, dynamic> visuals = _getCategoryVisuals(cat);
                                      return _buildCategoryCard(
                                        category: cat,
                                        title: visuals['title'] as String,
                                        subtitle: visuals['subtitle'] as String,
                                        iconBgColor: visuals['iconBgColor'] as Color,
                                        iconColor: visuals['iconColor'] as Color,
                                        iconData: visuals['iconData'] as IconData,
                                        companies: categorized[cat] ?? <String>[],
                                        isDark: isDark,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('form_step'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selected company badge with Change button
                            Builder(builder: (context) {
                              final Map<String, dynamic>? meta = _getCompanyMeta(_company);
                              final Color brandColor = _parseHexColor(
                                meta != null ? meta['brand_color'] as String? : null,
                                const Color(0xFF0B1F3A),
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: brandColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: brandColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildCompanyLogo(_company, true),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _tr('Working with', 'काम करते हैं'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                          Text(
                                            _company,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: brandColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_detailsLocked)
                                      GestureDetector(
                                        onTap: () => setState(() => _formVisible = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _tr('Change', 'बदलें'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _riderIdController,
                              enabled: !_detailsLocked,
                              onChanged: (_) => setState(() {}),
                              decoration: _fieldDecoration(
                                label: _tr('Rider ID *', 'राइडर आईडी *'),
                                hint: _tr('Enter your rider ID', 'अपनी राइडर आईडी लिखें'),
                                isDark: isDark,
                                icon: Icons.badge_rounded,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _cityController,
                              enabled: !_detailsLocked,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              decoration: _fieldDecoration(
                                label: _tr('City *', 'शहर *'),
                                hint: _tr('Enter your city', 'अपना शहर लिखें'),
                                isDark: isDark,
                                icon: Icons.location_city_rounded,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: hasOtherCompany
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: TextField(
                                        controller: _otherCompanyController,
                                        enabled: !_detailsLocked,
                                        decoration: _fieldDecoration(
                                          label: _tr('Company name *', 'कंपनी का नाम *'),
                                          isDark: isDark,
                                          icon: Icons.storefront_rounded,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111827) : const Color(0xFFFFF3D1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.two_wheeler_rounded,
                                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _tr('Vehicle Details', 'वाहन की जानकारी'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _vehicleTypes.contains(_vehicleType) ? _vehicleType : 'ev_scooter',
                                    isExpanded: true,
                                    items: _vehicleTypes
                                        .map(
                                          (String type) => DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(_vehicleTypeLabel(type)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _detailsLocked
                                        ? null
                                        : (String? value) {
                                            if (value == null) return;
                                            setState(() {
                                              _vehicleType = value;
                                              _hasEv = value.startsWith('ev_');
                                            });
                                          },
                                    decoration: _fieldDecoration(
                                      label: _tr('Vehicle type *', 'वाहन का प्रकार *'),
                                      isDark: isDark,
                                      icon: Icons.category_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _evModelController,
                                    enabled: !_detailsLocked,
                                    onChanged: (_) => setState(() {}),
                                    decoration: _fieldDecoration(
                                      label: _tr('Vehicle model', 'वाहन मॉडल'),
                                      hint: _tr('e.g. Ola S1, Hero bike', 'जैसे Ola S1, Hero बाइक'),
                                      isDark: isDark,
                                      icon: Icons.electric_bike_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _evNumberController,
                                    enabled: !_detailsLocked,
                                    textCapitalization: TextCapitalization.characters,
                                    onChanged: (_) => setState(() {}),
                                    decoration: _fieldDecoration(
                                      label: _tr('Vehicle number *', 'वाहन नंबर *'),
                                      hint: _tr('Registration number', 'रजिस्ट्रेशन number'),
                                      isDark: isDark,
                                      icon: Icons.confirmation_number_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _purchaseYearController,
                                    enabled: !_detailsLocked,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    maxLength: 4,
                                    decoration: _fieldDecoration(
                                      label: _tr('Purchase year', 'खरीद का साल'),
                                      isDark: isDark,
                                      icon: Icons.calendar_month_rounded,
                                    ).copyWith(counterText: ''),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : (_detailsLocked
                                        ? () => setState(() => _detailsLocked = false)
                                        : _save),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(_detailsLocked ? Icons.lock_open_rounded : Icons.check_circle_rounded),
                                label: Text(
                                  _detailsLocked
                                      ? _tr('Unlock & Edit Details', 'अनलॉक और एडिट करें')
                                      : (_saving
                                            ? _tr('Saving...', 'सेव हो रहा है...')
                                            : _tr('Save onboarding details', 'ऑनबोर्डिंग जानकारी सेव करें')),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                                  backgroundColor: _detailsLocked ? const Color(0xFFF4B400) : const Color(0xFF0B1F3A),
                                  foregroundColor: _detailsLocked ? const Color(0xFF0B1F3A) : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    this.initialCity,
    this.showAppBar = false,
  });

  /// Prefills city when it matches a known option (e.g. from profile).
  final String? initialCity;
  final bool showAppBar;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const String _apiAccessKey = ApiConfig.apiAccessKey;
  static const List<String> _fallbackCities = ['Delhi', 'Noida', 'Gurgaon'];
  static const List<String> _fallbackCompanies = ['Blinkit', 'Zepto', 'Swiggy', 'Other'];
  static const List<String> _fallbackIssueTypes = ['Payment', 'Safety', 'Account', 'Route'];

  final TextEditingController _bodyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _anonymous = false;
  List<String> _cities = List<String>.from(_fallbackCities);
  List<String> _companies = List<String>.from(_fallbackCompanies);
  List<String> _issueTypes = List<String>.from(_fallbackIssueTypes);
  late String _selectedCity;
  late String _selectedCompany;
  late String _selectedType;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _submitting = false;
  bool _metaLoading = true;

  String get _apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  @override
  void initState() {
    super.initState();
    _selectedCity = _cities.first;
    _selectedCompany = _companies.first;
    _selectedType = _issueTypes.first;
    final String? hint = widget.initialCity?.trim();
    if (hint != null && hint.isNotEmpty && _cities.contains(hint)) {
      _selectedCity = hint;
    }
    _loadPostMeta();
  }

  List<String> _labelsFromMetaList(dynamic raw) {
    if (raw is! List<dynamic>) return [];
    final List<String> out = [];
    for (final dynamic item in raw) {
      if (item is Map && item['label'] is String) {
        final String s = (item['label'] as String).trim();
        if (s.isNotEmpty) {
          out.add(s);
        }
      }
    }
    return out;
  }

  void _ensureSelectionsFitOptions() {
    if (!_cities.contains(_selectedCity)) {
      _selectedCity = _cities.first;
    }
    if (!_companies.contains(_selectedCompany)) {
      _selectedCompany = _companies.first;
    }
    if (!_issueTypes.contains(_selectedType)) {
      _selectedType = _issueTypes.first;
    }
  }

  Future<void> _loadPostMeta() async {
    try {
      final Uri uri = Uri.parse('$_apiBaseUrl/api/v1/posts/meta');
      final http.Response res = await http.get(
        uri,
        headers: <String, String>{'X-API-Key': _apiAccessKey},
      );
      if (res.statusCode != 200 || !mounted) {
        return;
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      final List<String> cities = _labelsFromMetaList(decoded['cities']);
      final List<String> companies = _labelsFromMetaList(decoded['companies']);
      final List<String> issueTypes = _labelsFromMetaList(decoded['issue_types']);
      if (cities.isEmpty || companies.isEmpty || issueTypes.isEmpty) {
        return;
      }
      setState(() {
        _cities = cities;
        _companies = companies;
        _issueTypes = issueTypes;
        final String? hint = widget.initialCity?.trim();
        if (hint != null && hint.isNotEmpty && _cities.contains(hint)) {
          _selectedCity = hint;
        }
        _ensureSelectionsFitOptions();
      });
    } catch (_) {
      // Keep fallback lists from initState.
    } finally {
      if (mounted) {
        setState(() => _metaLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFileName = x.name;
    });
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
    });
  }

  Future<void> _submitPost() async {
    final String rawBody = _bodyController.text.trim();
    if (rawBody.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something about your issue.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String token = (prefs.getString('session_access_token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login karo pehle â€” post bhejne ke liye access token chahiye.'),
        ),
      );
      return;
    }

    final String composedBody = '[$_selectedType]\n\n$rawBody';

    setState(() => _submitting = true);
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/v1/posts');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['X-API-Key'] = _apiAccessKey
        ..fields['body'] = composedBody
        ..fields['city'] = _selectedCity
        ..fields['company'] = _selectedCompany
        ..fields['is_anonymous'] = _anonymous.toString();

      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        final String name = (_imageFileName != null && _imageFileName!.isNotEmpty)
            ? _imageFileName!
            : 'post.jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            _imageBytes!,
            filename: name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 201) {
        _bodyController.clear();
        _clearImage();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post live ho gaya. Community dekh legi.')),
        );
        return;
      }

      String message = 'Post nahi bhej paaye (${response.statusCode}).';
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String) {
            message = detail;
          } else if (detail is List && detail.isNotEmpty && detail.first is Map) {
            final first = detail.first as Map;
            final msg = first['msg'];
            if (msg is String) message = msg;
          }
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 390;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget content = Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF1F2937), Color(0xFF111827)]
                      : const [Color(0xFFFFFFFF), Color(0xFFF5F8FF)],
                ),
                border: Border.all(color: isDark ? const Color(0x335B6B88) : const Color(0x261D4ED8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF1D4ED8),
                        child: Icon(Icons.edit_note_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Naya post',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF102A56),
                        ),
                      ),
                    ],
                  ),
                  if (_metaLoading) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Issue clear likho â€” city, company, aur type se riders jaldi samajh lenge.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bodyController,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Problem yahan likhoâ€¦',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : null,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0x335B6B88) : const Color(0x331D4ED8),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0x335B6B88) : const Color(0x331D4ED8),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _CreateDropdown(
                        title: 'City',
                        value: _selectedCity,
                        options: _cities,
                        enabled: !_metaLoading,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCity = value);
                          }
                        },
                      ),
                      _CreateDropdown(
                        title: 'Company',
                        value: _selectedCompany,
                        options: _companies,
                        enabled: !_metaLoading,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCompany = value);
                          }
                        },
                      ),
                      _CreateDropdown(
                        title: 'Type',
                        value: _selectedType,
                        options: _issueTypes,
                        enabled: !_metaLoading,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _anonymous
                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.32) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFF)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _anonymous
                            ? const Color(0x661D4ED8)
                            : (isDark ? const Color(0x335B6B88) : const Color(0x221D4ED8)),
                      ),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _anonymous,
                        onChanged: (_submitting || _metaLoading)
                            ? null
                            : (v) => setState(() => _anonymous = v),
                        title: Text(
                          'Anonymous post',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          'Feed par naam hide; admin dekh sakta hai.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(
                            _imageBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                              child: IconButton(
                                onPressed: _submitting ? null : _clearImage,
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_submitting || _metaLoading) ? null : _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_imageBytes == null ? 'Photo add karo' : 'Photo badlo'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 12 : 16,
                            vertical: compact ? 10 : 12,
                          ),
                          side: const BorderSide(color: Color(0x661D4ED8)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: (_submitting || _metaLoading) ? null : _submitPost,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_submitting ? 'Bhej raheâ€¦' : 'Post karo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 14 : 18,
                            vertical: compact ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
      ),
      body: content,
    );
  }
}

class _CreateDropdown extends StatelessWidget {
  const _CreateDropdown({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 152,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: options
            .map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
            .toList(),
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: title,
          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : null),
          filled: true,
          fillColor: isDark ? const Color(0xFF111827) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? const Color(0x335B6B88) : const Color(0x331D4ED8),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? const Color(0x335B6B88) : const Color(0x331D4ED8),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1D4ED8)),
          ),
        ),
      ),
    );
  }
}

class EvScreen extends StatefulWidget {
  const EvScreen({
    super.key,
    required this.currentUserCity,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
  });

  final String currentUserCity;
  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;

  @override
  State<EvScreen> createState() => _EvScreenState();
}

class _EvScreenState extends State<EvScreen> {
  static const List<List<Color>> _evTileGradients = <List<Color>>[
    <Color>[Color(0xFF4F46E5), Color(0xFF7C3AED)], // Indigo to Purple
    <Color>[Color(0xFFEA580C), Color(0xFFF59E0B)], // Orange to Amber
    <Color>[Color(0xFF0D9488), Color(0xFF10B981)], // Teal to Emerald
    <Color>[Color(0xFF2563EB), Color(0xFF06B6D4)], // Blue to Cyan
  ];

  late Future<ContactLayoutMeta> _layoutFuture;
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _layoutFuture = fetchContactLayoutMeta(
      apiBaseUrl: widget.apiBaseUrl,
      apiAccessKey: widget.apiAccessKey,
    );
  }

  void _openEvAction({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    String? contactInquiryKind,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EvActionDetailScreen(
          title: title,
          description: description,
          icon: icon,
          contactInquiryKind: contactInquiryKind,
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
        ),
      ),
    );
  }

  void _openRentEv(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RentEvScreen(
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  void _openBuyEv(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuyEvScreen(
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  void _openChargingStations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChargingStationsScreen(
          initialCity: widget.currentUserCity,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool compact = screenWidth < 600;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E3A8A), // Indigo Blue
                  Color(0xFFEA580C), // Electric Orange
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Glowing abstract background circle 1
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                // Glowing abstract background circle 2
                Positioned(
                  left: -50,
                  bottom: -50,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                // Rotated background EV moped icon
                Positioned(
                  right: -10,
                  bottom: -15,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Icon(
                      Icons.electric_moped_rounded,
                      size: 110,
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Tag Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: Color(0xFFF59E0B),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _tr('EV HUB', 'ईवी हब'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _tr('EV Support Hub', 'ईवी सपोर्ट हब'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(
                          'Rent, buy and maintain EVs with rider-friendly plans.',
                          'राइडर-फ्रेंडली प्लान्स के साथ ईवी रेंट करें, खरीदें और मेंटेन करें।',
                        ),
                        style: const TextStyle(
                          color: Color(0xF2FFFFFF),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final int columns = compact ? 2 : 3;
            final double spacing = 12;
            final double cardWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            final double cardHeight = compact ? 130 : 122;

            return FutureBuilder<ContactLayoutMeta>(
              future: _layoutFuture,
              builder: (context, snapshot) {
                final List<Widget> evHub = <Widget>[];
                if (snapshot.hasData) {
                  int gi = 0;
                  for (final InquiryIssueTile t in snapshot.data!.evHubTiles) {
                    final List<Color> g = _evTileGradients[gi % _evTileGradients.length];
                    gi++;
                    evHub.add(
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: _EvQuickActionCard(
                          title: t.title,
                          subtitle: t.subtitle,
                          icon: inquiryIssueIcon(t.iconKey),
                          colorA: g[0],
                          colorB: g[1],
                          onTap: () => _openEvAction(
                            context: context,
                            title: t.title,
                            description: t.detailDescription,
                            icon: inquiryIssueIcon(t.iconKey),
                            contactInquiryKind: t.slug,
                          ),
                        ),
                      ),
                    );
                  }
                }

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _EvQuickActionCard(
                        title: _tr('Rent EV', 'ईवी किराए पर लें'),
                        subtitle: _tr('Daily plans', 'डेली प्लान्स'),
                        icon: Icons.electric_scooter_rounded,
                        colorA: const Color(0xFF4F46E5), // Premium Indigo
                        colorB: const Color(0xFF7C3AED), // Premium Violet
                        onTap: () => _openRentEv(context),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _EvQuickActionCard(
                        title: _tr('Buy EV', 'ईवी खरीदें'),
                        subtitle: _tr('Best offers', 'बेस्ट ऑफर्स'),
                        icon: Icons.electric_bike_rounded,
                        colorA: const Color(0xFFEA580C), // Premium Orange
                        colorB: const Color(0xFFF59E0B), // Premium Amber
                        onTap: () => _openBuyEv(context),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _EvQuickActionCard(
                        title: _tr('Charging', 'चार्जिंग'),
                        subtitle: _tr('Nearby points', 'नज़दीकी पॉइंट्स'),
                        icon: Icons.ev_station_rounded,
                        colorA: const Color(0xFF0D9488), // Premium Teal
                        colorB: const Color(0xFF10B981), // Premium Emerald
                        onTap: () => _openChargingStations(context),
                      ),
                    ),
                    ...evHub,
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ChargingStationsScreen extends StatefulWidget {
  const _ChargingStationsScreen({
    required this.initialCity,
    this.languageCode = 'en',
  });

  final String initialCity;
  final String languageCode;

  @override
  State<_ChargingStationsScreen> createState() => _ChargingStationsScreenState();
}

class _ChargingStationsScreenState extends State<_ChargingStationsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('Charging Stations', 'चार्जिंग स्टेशन')),
      ),
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('Nearest EV Charging', 'नज़दीकी ईवी चार्जिंग'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _tr(
                    'Live location first, then city-wise lists - scroll for more stations.',
                    'पहले लाइव लोकेशन, फिर शहर के हिसाब से लिस्ट - और स्टेशनों के लिए स्क्रॉल करें।',
                  ),
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EvChargingLocationsSection(
            initialCity: widget.initialCity,
            scrollController: _scrollController,
            languageCode: widget.languageCode,
          ),
        ],
      ),
    );
  }
}

class _EvQuickActionCard extends StatelessWidget {
  const _EvQuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorA,
    required this.colorB,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color colorA;
  final Color colorB;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorA.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorA, colorB],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  // Subtle abstract background bubble
                  Positioned(
                    right: -15,
                    bottom: -15,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Clickable Chevron at the top right
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 21),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
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
        ),
      ),
    );
  }
}

class _EvChargingLocationsSection extends StatefulWidget {
  const _EvChargingLocationsSection({
    required this.initialCity,
    this.scrollController,
    this.languageCode = 'en',
  });

  final String initialCity;
  final ScrollController? scrollController;
  final String languageCode;

  @override
  State<_EvChargingLocationsSection> createState() => _EvChargingLocationsSectionState();
}

class _EvChargingLocationsSectionState extends State<_EvChargingLocationsSection> {
  static const String _apiAccessKey = ApiConfig.apiAccessKey;
  static const int _pageSize = 20;

  String _selectedCity = 'All';
  double? _refLat;
  double? _refLon;
  /// True when using a fresh device GPS fix for this screen visit (never persisted â€” riders move).
  bool _refFromGps = false;
  bool _isDetectingLocation = false;

  final List<_EvLocationItem> _items = [];
  int _totalCount = 0;
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _loadError;

  final Set<String> _cityChoices = {'All'};
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    final city = widget.initialCity.trim();
    if (city.isNotEmpty) {
      _cityChoices.add(city);
    }
    _applyCityCenterFallbackIfNeeded();
    widget.scrollController?.addListener(_onParentScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapThenLoad());
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onParentScroll);
    super.dispose();
  }

  void _onParentScroll() {
    final ScrollController? c = widget.scrollController;
    if (c == null || !c.hasClients) return;
    if (_loadingInitial || _loadingMore || !_hasMore || _loadError != null) return;
    final ScrollPosition pos = c.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      _fetchPage(reset: false);
    }
  }

  /// Approximate city center for NCR â€” used so distances always show in km without pressing Detect me.
  ({double lat, double lon}) _ncrApproxCenter(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.contains('gurgaon') || c.contains('gurugram')) return (lat: 28.4595, lon: 77.0266);
    if (c.contains('noida')) return (lat: 28.5355, lon: 77.3910);
    if (c.contains('delhi')) return (lat: 28.6139, lon: 77.2090);
    if (c.contains('faridabad')) return (lat: 28.4089, lon: 77.3178);
    return (lat: 28.55, lon: 77.25);
  }

  String get _profileCity => widget.initialCity.trim();
  String get _profileFallbackLabel =>
      _profileCity.isEmpty
          ? _tr('default NCR area', 'डिफ़ॉल्ट NCR एरिया')
          : _tr('your profile city', 'आपका प्रोफाइल शहर');

  void _applyCityCenterFallbackIfNeeded() {
    if (_refLat != null && _refLon != null) return;
    final o = _ncrApproxCenter(_profileCity);
    _refLat = o.lat;
    _refLon = o.lon;
    _refFromGps = false;
  }

  void _fallbackToProfileCity({bool setCityFilter = true}) {
    final String profileCity = _profileCity;
    if (setCityFilter && profileCity.isNotEmpty) {
      _selectedCity = profileCity;
      _cityChoices.add(profileCity);
    }
    final o = _ncrApproxCenter(profileCity);
    _refLat = o.lat;
    _refLon = o.lon;
    _refFromGps = false;
  }

  Future<void> _bootstrapThenLoad() async {
    _applyCityCenterFallbackIfNeeded();
    if (mounted) {
      setState(() {});
    }
    final bool gpsOk = await _tryInitialGps(const Duration(seconds: 6));
    if (gpsOk && mounted) {
      setState(() {
        _selectedCity = 'All';
      });
    } else if (!gpsOk && mounted) {
      setState(() {
        _fallbackToProfileCity(setCityFilter: true);
      });
    }
    if (!mounted) return;
    await _loadCityChoices();
    if (!mounted) return;
    await _fetchPage(reset: true);
    if (!mounted) return;
    if (gpsOk) {
      await _syncCityFromNearestResult();
    }
  }

  Future<bool> _tryInitialGps(Duration timeout) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(timeout);
      if (!mounted) return false;
      setState(() {
        _refLat = pos.latitude;
        _refLon = pos.longitude;
        _refFromGps = true;
      });
      return true;
    } catch (_) {
      // Profile city center used until rider taps Detect me.
      return false;
    }
  }

  String get _apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  Future<void> _loadCityChoices() async {
    try {
      final Uri uri = Uri.parse('$_apiBaseUrl/api/v1/ev/cities');
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiAccessKey,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final Map<String, dynamic> jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> raw = jsonBody['cities'] as List<dynamic>? ?? const [];
      final Set<String> next = {..._cityChoices};
      for (final dynamic e in raw) {
        final String s = '$e'.trim();
        if (s.isNotEmpty) next.add(s);
      }
      if (!mounted) return;
      setState(() {
        _cityChoices
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      // Keep All + profile city only.
    }
  }

  List<_EvLocationItem> _withDistances(List<_EvLocationItem> raw) {
    if (_refLat == null || _refLon == null) return raw;
    return raw
        .map((item) {
          final double meters = Geolocator.distanceBetween(
            _refLat!,
            _refLon!,
            item.latitude,
            item.longitude,
          );
          return item.copyWith(distanceKm: meters / 1000);
        })
        .toList(growable: false);
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (_loadingMore && !reset) return;
    if (!reset && (!_hasMore || _loadingInitial)) return;

    if (reset) {
      setState(() {
        _loadingInitial = true;
        _loadError = null;
        _items.clear();
        _totalCount = 0;
        _hasMore = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final int offset = reset ? 0 : _items.length;
    final Map<String, String> qp = <String, String>{
      'limit': '$_pageSize',
      'offset': '$offset',
    };
    if (_selectedCity != 'All' && _selectedCity.trim().isNotEmpty) {
      qp['city'] = _selectedCity.trim();
    }
    if (_refLat != null && _refLon != null) {
      qp['near_lat'] = '${_refLat!}';
      qp['near_lon'] = '${_refLon!}';
    }

    try {
      final Uri uri = Uri.parse('$_apiBaseUrl/api/v1/ev/locations').replace(queryParameters: qp);
      final http.Response response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiAccessKey,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final Map<String, dynamic> jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final int total = (jsonBody['total'] as num?)?.toInt() ?? 0;
      final List<dynamic> chunk = jsonBody['items'] as List<dynamic>? ?? const [];
      final List<_EvLocationItem> parsed = chunk
          .whereType<Map<String, dynamic>>()
          .map(_EvLocationItem.fromJson)
          .toList(growable: false);
      final List<_EvLocationItem> withKm = _withDistances(parsed);

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(withKm);
        } else {
          _items.addAll(withKm);
        }
        _totalCount = total;
        _hasMore = _items.length < _totalCount;
        for (final _EvLocationItem it in withKm) {
          if (it.city.isNotEmpty) _cityChoices.add(it.city);
        }
        _loadingInitial = false;
        _loadingMore = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        _loadingMore = false;
        _loadError = 'Could not load stations ($e)';
      });
    }
  }

  Future<void> _detectMe() async {
    setState(() => _isDetectingLocation = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _fallbackToProfileCity(setCityFilter: true);
        });
        await _fetchPage(reset: true);
        _showHint('Live location not available, showing stations from $_profileFallbackLabel.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _fallbackToProfileCity(setCityFilter: true);
        });
        await _fetchPage(reset: true);
        _showHint('Location permission denied. Showing stations from $_profileFallbackLabel.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _refLat = position.latitude;
        _refLon = position.longitude;
        _refFromGps = true;
        _selectedCity = 'All';
      });
      await _fetchPage(reset: true);
      if (!mounted) return;
      await _syncCityFromNearestResult();
    } catch (_) {
      setState(() {
        _fallbackToProfileCity(setCityFilter: true);
      });
      await _fetchPage(reset: true);
      _showHint('Could not detect live location. Showing stations from $_profileFallbackLabel.');
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  String? _nearestCityFromItems() {
    if (_items.isEmpty) return null;
    _EvLocationItem? best;
    for (final _EvLocationItem item in _items) {
      final String city = item.city.trim();
      if (city.isEmpty) continue;
      if (best == null) {
        best = item;
        continue;
      }
      final double a = item.distanceKm ?? double.infinity;
      final double b = best.distanceKm ?? double.infinity;
      if (a < b) {
        best = item;
      }
    }
    if (best == null) return null;
    final String nextCity = best.city.trim();
    return nextCity.isEmpty ? null : nextCity;
  }

  Future<void> _syncCityFromNearestResult() async {
    if (!_refFromGps) return;
    final String? nearestCity = _nearestCityFromItems();
    if (nearestCity == null || nearestCity == _selectedCity) return;
    if (!mounted) return;
    setState(() {
      _selectedCity = nearestCity;
      _cityChoices.add(nearestCity);
    });
    await _fetchPage(reset: true);
  }

  void _showHint(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDistanceKm(double km) {
    if (km < 100) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  String _distanceSubtitleSuffix() {
    if (_refFromGps) return 'from your location';
    final String c = widget.initialCity.trim();
    if (c.isEmpty) return 'approx. from NCR center';
    return 'approx. from $c area';
  }

  void _clearGpsReference() {
    setState(() {
      _refLat = null;
      _refLon = null;
      _refFromGps = false;
      _applyCityCenterFallbackIfNeeded();
    });
    _fetchPage(reset: true);
  }

  Future<void> _openInGoogleMaps(_EvLocationItem item) async {
    final String url = 'https://www.google.com/maps/search/?api=1&query=${item.latitude},${item.longitude}';
    final opened = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showHint(_tr('Could not open Google Maps right now.', 'अभी Google Maps नहीं खुल पाया।'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? const Color(0xFF111827) : const Color(0xFFE8EDF5),
        border: Border.all(color: isDark ? const Color(0x405B6B88) : const Color(0x331D4ED8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('Charging points from map', 'मैप से चार्जिंग पॉइंट्स'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tr(
              'We wait briefly for live GPS, then load your city in pages (scroll down for more). Nothing is cached - tap Detect me anytime to refresh.',
              'हम पहले थोड़ी देर लाइव GPS का इंतज़ार करते हैं, फिर आपका शहर पेज में लोड होता है (और देखने के लिए नीचे स्क्रॉल करें)। कुछ भी कैश नहीं होता - रिफ्रेश के लिए कभी भी Detect me दबाएं।',
            ),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final List<String> sortedCities = _cityChoices.toList()..sort();
              final String cityFilter = sortedCities.contains(_selectedCity) ? _selectedCity : 'All';
              if (cityFilter != _selectedCity) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCity = cityFilter);
                });
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: _tr('City filter', 'शहर फ़िल्टर'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            contentPadding: EdgeInsetsDirectional.only(start: 12, end: 8, top: 4, bottom: 4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: cityFilter,
                              isExpanded: true,
                              isDense: true,
                              items: sortedCities
                                  .map(
                                    (city) => DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedCity = value);
                                _fetchPage(reset: true);
                              },
                            ),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isDetectingLocation ? null : _detectMe,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(_tr('Detect me', 'मेरी लोकेशन')),
                      ),
                      if (_refFromGps)
                        OutlinedButton(
                          onPressed: _clearGpsReference,
                          child: Text(_tr('Clear GPS', 'GPS हटाएं')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loadError != null
                        ? _loadError!
                        : _loadingInitial && _items.isEmpty
                            ? _tr(
                                'Getting location & loading first page...',
                                'लोकेशन ली जा रही है और पहला पेज लोड हो रहा है...',
                              )
                            : _refFromGps
                                ? _tr(
                                    'Loaded ${_items.length} of $_totalCount - nearest first (GPS) - scroll for more',
                                    '${_totalCount} में से ${_items.length} लोड - पहले सबसे नज़दीकी (GPS) - और देखने के लिए स्क्रॉल करें',
                                  )
                                : _tr(
                                    'Loaded ${_items.length} of $_totalCount - nearest first (approx.) - scroll for more',
                                    '${_totalCount} में से ${_items.length} लोड - पहले सबसे नज़दीकी (अनुमानित) - और देखने के लिए स्क्रॉल करें',
                                  ),
                    style: TextStyle(
                      fontSize: 12,
                      color: _loadError != null
                          ? const Color(0xFFB91C1C)
                          : isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _fetchPage(reset: true),
                      child: Text(_tr('Retry', 'फिर कोशिश करें')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_loadingInitial && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_loadingInitial && _items.isEmpty && _loadError == null)
                    Text(
                      _tr('No charging points found for current filters.', 'मौजूदा फ़िल्टर के लिए कोई चार्जिंग पॉइंट नहीं मिला।'),
                      style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334E68)),
                    )
                  else if (_items.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._items.map((item) {
                        final scheme = Theme.of(context).colorScheme;
                        final cardBg = isDark ? const Color(0xFF152238) : scheme.surface;
                        final detail = item.cardDetailLine;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: isDark ? 4 : 8,
                          shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                          surfaceTintColor: Colors.transparent,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isDark ? const Color(0x334E648C) : const Color(0x221D4ED8),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openInGoogleMaps(item),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x402563EB),
                                              blurRadius: 12,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.ev_station_rounded, color: Colors.white, size: 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 18,
                                                height: 1.2,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (item.distanceKm != null) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.near_me_rounded,
                                                    size: 18,
                                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '${_formatDistanceKm(item.distanceKm!)} Â· ${_distanceSubtitleSuffix()}',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: -0.1,
                                                        color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1E3A5F) : const Color(0x1F2563EB),
                                                    borderRadius: BorderRadius.circular(999),
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF3B82F6) : const Color(0x332563EB),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.city.isNotEmpty
                                                        ? item.city
                                                        : _tr('City unknown', 'शहर अज्ञात'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (detail.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Text(
                                                detail,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark ? const Color(0x22334155) : const Color(0xFFE2E8F0),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _openInGoogleMaps(item),
                                    icon: const Icon(Icons.map_rounded, size: 18),
                                    label: Text(_tr('Get directions on Maps', 'Maps पर दिशा देखें')),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EvLocationItem {
  _EvLocationItem({
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.summary,
    required this.stationCode,
    this.distanceKm,
  });

  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String city;
  final String summary;
  final String stationCode;
  final double? distanceKm;

  /// Single friendly subtitle for list cards â€” never raw KML / QIS ID dumps.
  String get cardDetailLine {
    final addr = address.trim();
    if (addr.isNotEmpty && !_looksLikeTechnicalDump(addr)) return addr;
    return summary.trim();
  }

  static bool _looksLikeTechnicalDump(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('qis id')) return true;
    if (lower.contains('qis name') && lower.contains('site type')) return true;
    final labelHits = RegExp(r'\b[a-z][a-z0-9 /]+\s*:', caseSensitive: false).allMatches(lower).length;
    return labelHits >= 3;
  }

  factory _EvLocationItem.fromJson(Map<String, dynamic> json) {
    final rawDescription = (json['description'] as String? ?? '');
    final details = _extractDetails(rawDescription);
    final cityFromDescription = details['City'] ?? _extractCity(rawDescription);
    final stationCode = details['QIS ID/No.'] ?? details['QIS ID'] ?? '';
    final qisName = details['QIS Name'] ?? '';
    final siteType = details['Site Type'] ?? '';
    final summaryParts = [if (qisName.isNotEmpty) qisName, if (siteType.isNotEmpty) siteType];
    final summary = summaryParts.join(' â€¢ ');
    final cleanedDescription = _stripHtml(rawDescription);
    return _EvLocationItem(
      name: (json['name'] as String? ?? 'Unknown location'),
      description: cleanedDescription,
      address: (json['address'] as String? ?? ''),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      city: cityFromDescription,
      summary: summary,
      stationCode: stationCode,
    );
  }

  _EvLocationItem copyWith({double? distanceKm}) {
    return _EvLocationItem(
      name: name,
      description: description,
      address: address,
      latitude: latitude,
      longitude: longitude,
      city: city,
      summary: summary,
      stationCode: stationCode,
      distanceKm: distanceKm,
    );
  }

  static String _stripHtml(String value) {
    var cleaned = value.replaceAll('<br>', '\n').replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll('\n', ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'unnamed\s*\(\d+\)\s*:\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(Lat|Long|Sr\.No|Unique ID2)\s*:\s*[^ ]+', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return cleaned;
  }

  static Map<String, String> _extractDetails(String rawDescription) {
    final text = rawDescription.replaceAll('<br>', '\n').replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final output = <String, String>{};
    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      final keyLower = key.toLowerCase();
      if (value.isEmpty) continue;
      if (keyLower.contains('unnamed')) continue;
      if (keyLower == 'lat' || keyLower == 'long' || keyLower == 'sr.no' || keyLower == 'unique id2') {
        continue;
      }
      output[key] = value;
    }
    return output;
  }

  static String _extractCity(String description) {
    final match = RegExp(r'City:\s*([^<\n\r]+)', caseSensitive: false).firstMatch(description);
    if (match == null) return '';
    return (match.group(1) ?? '').trim();
  }
}

class _EvActionDetailScreen extends StatefulWidget {
  const _EvActionDetailScreen({
    required this.title,
    required this.description,
    required this.icon,
    this.contactInquiryKind,
    this.apiBaseUrl,
    this.apiAccessKey,
    this.accessToken,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Help flows: post to contact API with this kind (message only; identity from profile).
  final String? contactInquiryKind;
  final String? apiBaseUrl;
  final String? apiAccessKey;
  final String? accessToken;

  @override
  State<_EvActionDetailScreen> createState() => _EvActionDetailScreenState();
}

class _EvActionDetailScreenState extends State<_EvActionDetailScreen> {
  static final Map<String, String> _memoryDraftStore = <String, String>{};
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _requirementController;
  bool _submitted = false;
  bool _submitting = false;

  bool get _contactMode =>
      (widget.contactInquiryKind ?? '').isNotEmpty &&
      (widget.apiBaseUrl ?? '').isNotEmpty &&
      (widget.apiAccessKey ?? '').isNotEmpty;

  bool get _loggedIn => (widget.accessToken ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _requirementController = TextEditingController();
    _loadSavedDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDraft() async {
    if (_contactMode) {
      final String k = widget.contactInquiryKind!;
      String message = '';
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        message = prefs.getString('help_contact_${k}_message') ?? '';
      } on MissingPluginException {
        message = _memoryDraftStore['help_contact_${k}_message'] ?? '';
      }
      if (!mounted) {
        return;
      }
      setState(() => _requirementController.text = message);
      return;
    }

    final String prefix = widget.title.toLowerCase().replaceAll(' ', '_');
    String name = '';
    String phone = '';
    String requirement = '';

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      name = prefs.getString('ev_${prefix}_name') ?? '';
      phone = prefs.getString('ev_${prefix}_phone') ?? '';
      requirement = prefs.getString('ev_${prefix}_requirement') ?? '';
    } on MissingPluginException {
      name = _memoryDraftStore['ev_${prefix}_name'] ?? '';
      phone = _memoryDraftStore['ev_${prefix}_phone'] ?? '';
      requirement = _memoryDraftStore['ev_${prefix}_requirement'] ?? '';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _nameController.text = name;
      _phoneController.text = phone;
      _requirementController.text = requirement;
    });
  }

  Future<void> _persistContactDraft(String message) async {
    final String k = widget.contactInquiryKind!;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('help_contact_${k}_message', message);
    } on MissingPluginException {
      _memoryDraftStore['help_contact_${k}_message'] = message;
    }
  }

  Future<void> _showContactSubmitSuccess() async {
    if (!mounted) {
      return;
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 40,
              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
            ),
          ),
          title: Text(
            '${widget.title} â€” received',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          content: Text(
            'Your message is saved with our team. Weâ€™ll reply using your profile email or phone, usually within 1â€“2 business days.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF059669),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _submitContactBacked() async {
    if (!_loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log in to submit â€” we attach your profile automatically.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final String message = _requirementController.text.trim();
    if (message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message must be at least 10 characters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await submitContact(
        apiBaseUrl: widget.apiBaseUrl!,
        apiAccessKey: widget.apiAccessKey!,
        accessToken: widget.accessToken!,
        inquiryKind: widget.contactInquiryKind!,
        message: message,
      );
      await _persistContactDraft('');
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      _requirementController.clear();
      await _showContactSubmitSuccess();
    } on ContactApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send. Try again.')),
      );
    }
  }

  Future<void> _submit() async {
    if (_contactMode) {
      await _submitContactBacked();
      return;
    }

    final String prefix = widget.title.toLowerCase().replaceAll(' ', '_');
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String requirement = _requirementController.text.trim();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('ev_${prefix}_name', name);
      await prefs.setString('ev_${prefix}_phone', phone);
      await prefs.setString('ev_${prefix}_requirement', requirement);
    } on MissingPluginException {
      _memoryDraftStore['ev_${prefix}_name'] = name;
      _memoryDraftStore['ev_${prefix}_phone'] = phone;
      _memoryDraftStore['ev_${prefix}_requirement'] = requirement;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _submitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F766E),
        content: Text('${widget.title} request saved locally'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    InputDecoration themedInput({
      required String label,
      bool alignWithHint = false,
    }) {
      final Color border = isDark ? const Color(0x335B6B88) : const Color(0x33FFB300);
      return InputDecoration(
        labelText: label,
        alignLabelWithHint: alignWithHint,
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0B1F3A), width: 1.2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1F2937), Color(0xFF0F172A)]
                    : const [Color(0xFF0B1F3A), Color(0xFFB45309)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0x33FFFFFF),
                  child: Icon(widget.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_contactMode) ...[
            const SizedBox(height: 14),
            Text(
              _loggedIn
                  ? 'Your name, email and phone come from your profile â€” just add your message below.'
                  : 'Log in to send this to our team (we use your profile details automatically).',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
          if (!_contactMode) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: themedInput(label: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: themedInput(label: 'Phone number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(height: _contactMode ? 14 : 0),
          TextField(
            controller: _requirementController,
            maxLines: _contactMode ? 5 : 3,
            onChanged: _contactMode
                ? (_) {
                    unawaited(_persistContactDraft(_requirementController.text));
                  }
                : null,
            decoration: themedInput(
              label: _contactMode ? 'Message' : 'Your requirement',
              alignWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          if (!_contactMode && _submitted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x140F766E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x330F766E)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Draft saved on device for quick reuse.',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: (_contactMode && _submitting) ? null : _submit,
            icon: _contactMode && _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_contactMode && _submitting ? 'Sendingâ€¦' : 'Submit request'),
          ),
        ],
      ),
    );
  }
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({
    super.key,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
  });

  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late Future<ContactLayoutMeta> _layoutFuture;
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _layoutFuture = fetchContactLayoutMeta(
      apiBaseUrl: widget.apiBaseUrl,
      apiAccessKey: widget.apiAccessKey,
    );
  }

  void _reloadLayout() {
    setState(() {
      _layoutFuture = fetchContactLayoutMeta(
        apiBaseUrl: widget.apiBaseUrl,
        apiAccessKey: widget.apiAccessKey,
      );
    });
  }

  void _openHelpForm(
    BuildContext context, {
    required String slug,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final String banner = description.trim().isEmpty
        ? _tr('Tell us more so we can help you faster.', 'हमें थोड़ा और बताएं ताकि हम जल्दी मदद कर सकें।')
        : description;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EvActionDetailScreen(
          title: title,
          description: banner,
          icon: icon,
          contactInquiryKind: slug,
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<ContactLayoutMeta>(
      future: _layoutFuture,
      builder: (BuildContext context, AsyncSnapshot<ContactLayoutMeta> snapshot) {
        final List<Widget> children = <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const <Color>[Color(0xFF1F2937), Color(0xFF0F172A)]
                    : const <Color>[Color(0xFF0B1F3A), Color(0xFFB45309)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isDark ? const Color(0x33000000) : const Color(0x33B45309),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr('Help & Support', 'मदद और सपोर्ट'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _tr(
                    'Report issues, track progress and get quick rider support.',
                    'समस्याएं बताएं, प्रगति ट्रैक करें और जल्दी राइडर सपोर्ट पाएं।',
                  ),
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _HelpActionTile(
            title: _tr('Contact us', 'हमसे संपर्क करें'),
            subtitle: _tr('Message the team (topic, your details)', 'टीम को संदेश भेजें (टॉपिक, आपकी जानकारी)'),
            icon: Icons.forward_to_inbox_rounded,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ContactScreen(
                    apiBaseUrl: widget.apiBaseUrl,
                    apiAccessKey: widget.apiAccessKey,
                    accessToken: widget.accessToken,
                    languageCode: widget.languageCode,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ];

        if (snapshot.connectionState == ConnectionState.waiting) {
          children.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _tr(
                      'Could not load help topics. Check connection and try again.',
                      'हेल्प टॉपिक्स लोड नहीं हुए। कनेक्शन चेक करें और फिर कोशिश करें।',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _reloadLayout,
                    child: Text(_tr('Retry', 'फिर कोशिश करें')),
                  ),
                ],
              ),
            ),
          );
        } else {
          final List<InquiryIssueTile> tiles = snapshot.data?.helpTiles ?? <InquiryIssueTile>[];
          for (final InquiryIssueTile t in tiles) {
            final IconData icon = inquiryIssueIcon(t.iconKey);
            children.add(
              _HelpActionTile(
                title: t.title,
                subtitle: t.subtitle,
                icon: icon,
                onTap: () => _openHelpForm(
                  context,
                  slug: t.slug,
                  title: t.title,
                  description: t.detailDescription,
                  icon: icon,
                ),
              ),
            );
            children.add(const SizedBox(height: 10));
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: children,
        );
      },
    );
  }
}

class _HelpActionTile extends StatelessWidget {
  const _HelpActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? const Color(0xFF1F2937) : Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: isDark ? const Color(0x335B6B88) : const Color(0x33FFB300),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFE9B5),
                child: Icon(
                  icon,
                  color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


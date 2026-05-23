import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'screens/screens.dart' as app_screens;

void main() {
  runApp(const RidersCommunityApp());
}

class RidersCommunityApp extends StatefulWidget {
  const RidersCommunityApp({super.key});

  @override
  State<RidersCommunityApp> createState() => _RidersCommunityAppState();
}

class _RidersCommunityAppState extends State<RidersCommunityApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isOnboardingComplete = false;
  bool _isLoggedIn = false;
  bool _isSessionLoading = true;
  bool _isCheckingVersion = false;
  Timer? _versionCheckTimer;
  bool _forceUpdateRequired = false;
  String _requiredVersion = '';
  String _updateMessage = '';
  String _currentUserName = 'Rider';
  String _currentUserHandle = '@rider';
  String _currentUserAvatarUrl = '';
  String _currentUserCity = '';
  String _currentUserPhone = '';
  String _accessToken = '';

  static const String _kThemeMode = 'session_theme_mode';
  static const String _kOnboardingDone = 'session_onboarding_done';
  static const String _kLoggedIn = 'session_logged_in';
  static const String _kAccessToken = 'session_access_token';
  static const String _kUserName = 'session_user_name';
  static const String _kUserHandle = 'session_user_handle';
  static const String _kUserAvatarUrl = 'session_user_avatar_url';
  static const String _kUserCity = 'session_user_city';
  static const String _kUserPhone = 'session_user_phone';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _versionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkVersionAndApply());
    }
  }

  Future<(bool forceUpdate, String requiredVersion, String message)> _fetchVersionGate() async {
    try {
      final Uri uri = Uri.parse('${ApiConfig.apiBaseUrl}/api/v1/update/check');
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-API-Key': ApiConfig.apiAccessKey,
        },
        body: jsonEncode(<String, dynamic>{
          'version_name': ApiConfig.appVersion,
        }),
      );
      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final bool upToDate = decoded['up_to_date'] == true;
          final bool forceUpdateFlag = decoded['force_update'] == true;
          final String requiredVersion = ('${decoded['required_version'] ?? ''}').trim();
          final String message = ('${decoded['message'] ?? ''}').trim();
          return (forceUpdateFlag || !upToDate, requiredVersion, message);
        }
      }
    } catch (_) {
      // If version check fails due to network/server issue, don't block app startup.
    }
    return (false, '', '');
  }

  void _startVersionRecheckLoop() {
    _versionCheckTimer?.cancel();
    _versionCheckTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_checkVersionAndApply());
    });
  }

  Future<void> _checkVersionAndApply() async {
    if (_isCheckingVersion || _isSessionLoading) return;
    _isCheckingVersion = true;
    try {
      final (bool forceUpdate, String requiredVersion, String message) = await _fetchVersionGate();
      if (!mounted) return;
      setState(() {
        _forceUpdateRequired = forceUpdate;
        _requiredVersion = requiredVersion;
        _updateMessage = message;
      });
    } finally {
      _isCheckingVersion = false;
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_kThemeMode) ?? 'light';
    final accessToken = prefs.getString(_kAccessToken) ?? '';
    final (bool forceUpdate, String requiredVersion, String updateMessage) =
        await _fetchVersionGate();

    if (!mounted) return;
    setState(() {
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _isOnboardingComplete = prefs.getBool(_kOnboardingDone) ?? false;
      _isLoggedIn = (prefs.getBool(_kLoggedIn) ?? false) && accessToken.isNotEmpty;
      _forceUpdateRequired = forceUpdate;
      _requiredVersion = requiredVersion;
      _updateMessage = updateMessage;
      _currentUserName = prefs.getString(_kUserName) ?? 'Rider';
      _currentUserHandle = prefs.getString(_kUserHandle) ?? '@rider';
      _currentUserAvatarUrl = prefs.getString(_kUserAvatarUrl) ?? '';
      _currentUserCity = prefs.getString(_kUserCity) ?? '';
      _currentUserPhone = prefs.getString(_kUserPhone) ?? '';
      _accessToken = accessToken;
      _isSessionLoading = false;
    });
    _startVersionRecheckLoop();
  }

  Future<void> _persistSession({
    bool? isOnboardingComplete,
    bool? isLoggedIn,
    ThemeMode? themeMode,
    String? accessToken,
    String? userName,
    String? userHandle,
    String? userAvatarUrl,
    String? userCity,
    String? userPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (isOnboardingComplete != null) {
      await prefs.setBool(_kOnboardingDone, isOnboardingComplete);
    }
    if (isLoggedIn != null) {
      await prefs.setBool(_kLoggedIn, isLoggedIn);
    }
    if (themeMode != null) {
      await prefs.setString(_kThemeMode, themeMode == ThemeMode.dark ? 'dark' : 'light');
    }
    if (accessToken != null) {
      await prefs.setString(_kAccessToken, accessToken);
    }
    if (userName != null) {
      await prefs.setString(_kUserName, userName);
    }
    if (userHandle != null) {
      await prefs.setString(_kUserHandle, userHandle);
    }
    if (userAvatarUrl != null) {
      await prefs.setString(_kUserAvatarUrl, userAvatarUrl);
    }
    if (userCity != null) {
      await prefs.setString(_kUserCity, userCity);
    }
    if (userPhone != null) {
      await prefs.setString(_kUserPhone, userPhone);
    }
  }

  String _phoneFromProfile(Map<String, dynamic> profile) {
    return ('${profile['phone_number'] ?? profile['phone'] ?? profile['mobile_number'] ?? ''}')
        .trim();
  }

  void _toggleTheme(bool isDark) {
    final nextMode = isDark ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      _themeMode = nextMode;
    });
    _persistSession(themeMode: nextMode);
  }

  void _completeOnboarding() {
    setState(() {
      _isOnboardingComplete = true;
    });
    _persistSession(isOnboardingComplete: true);
  }

  void _completeAuth(Map<String, dynamic> authData) {
    final String accessToken = (authData['access_token'] as String?) ?? '';
    final Map<String, dynamic> profile = (authData['profile'] as Map<String, dynamic>?) ?? {};
    final String fullName = ((profile['full_name'] as String?) ?? '').trim();
    final String username = ((profile['username'] as String?) ?? '').trim();
    final String profilePhotoUrl = ((profile['profile_photo_url'] as String?) ?? '').trim();
    final String city = ((profile['city'] as String?) ?? '').trim();
    final String profilePhone = _phoneFromProfile(profile);
    final String authPhone = ('${authData['phone_number'] ?? ''}').trim();
    final String phone = profilePhone.isNotEmpty ? profilePhone : authPhone;

    final String displayName = fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : 'Rider');
    final String handle = username.isNotEmpty ? '@$username' : '@rider';

    setState(() {
      _isLoggedIn = true;
      _accessToken = accessToken;
      _currentUserName = displayName;
      _currentUserHandle = handle;
      _currentUserAvatarUrl = profilePhotoUrl;
      _currentUserCity = city;
      _currentUserPhone = phone;
    });
    _persistSession(
      isLoggedIn: true,
      accessToken: accessToken,
      userName: displayName,
      userHandle: handle,
      userAvatarUrl: profilePhotoUrl,
      userCity: city,
      userPhone: phone,
    );
  }

  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _accessToken = '';
      _currentUserName = 'Rider';
      _currentUserHandle = '@rider';
      _currentUserAvatarUrl = '';
      _currentUserCity = '';
      _currentUserPhone = '';
    });
    _persistSession(
      isLoggedIn: false,
      accessToken: '',
      userName: 'Rider',
      userHandle: '@rider',
      userAvatarUrl: '',
      userCity: '',
      userPhone: '',
    );
  }

  void _applyProfileFromServer(Map<String, dynamic> profile) {
    final String fullName = ((profile['full_name'] as String?) ?? '').trim();
    final String username = ((profile['username'] as String?) ?? '').trim();
    final String profilePhotoUrl = ((profile['profile_photo_url'] as String?) ?? '').trim();
    final String city = ((profile['city'] as String?) ?? '').trim();
    final String phone = _phoneFromProfile(profile);
    final String displayName =
        fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : 'Rider');
    final String handle = username.isNotEmpty ? '@$username' : '@rider';
    setState(() {
      _currentUserName = displayName;
      _currentUserHandle = handle;
      _currentUserAvatarUrl = profilePhotoUrl;
      _currentUserCity = city;
      _currentUserPhone = phone;
    });
    _persistSession(
      userName: displayName,
      userHandle: handle,
      userAvatarUrl: profilePhotoUrl,
      userCity: city,
      userPhone: phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSessionLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Ride With Garv',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0B1F3A),
          onPrimary: Colors.white,
          secondary: Color(0xFFFFC928),
          onSecondary: Color(0xFF0B1F3A),
          surface: Color(0xFFFFFCF3),
          onSurface: Color(0xFF0B1F3A),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF9EA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.dark,
        ),
      ),
      home: _forceUpdateRequired
          ? _ForceUpdateRequiredScreen(
              requiredVersion: _requiredVersion,
              message: _updateMessage,
            )
          : !_isOnboardingComplete
              ? OnboardingScreen(onContinue: _completeOnboarding)
              : !_isLoggedIn
                  ? app_screens.AuthScreen(onAuthComplete: _completeAuth)
                  : app_screens.HomeScreen(
                      isDarkMode: _themeMode == ThemeMode.dark,
                      onThemeChanged: _toggleTheme,
                      onLogout: _logout,
                      accessToken: _accessToken,
                      onProfileSynced: _applyProfileFromServer,
                      currentUserName: _currentUserName,
                      currentUserHandle: _currentUserHandle,
                      currentUserAvatarUrl: _currentUserAvatarUrl,
                      currentUserCity: _currentUserCity,
                      currentUserPhone: _currentUserPhone,
                    ),
    );
  }
}

class _ForceUpdateRequiredScreen extends StatelessWidget {
  const _ForceUpdateRequiredScreen({
    required this.requiredVersion,
    required this.message,
  });

  final String requiredVersion;
  final String message;

  @override
  Widget build(BuildContext context) {
    final String resolvedMessage = message.trim().isEmpty
        ? 'Please update the app first to continue.'
        : message.trim();
    final String versionLabel =
        requiredVersion.trim().isEmpty ? 'latest version' : requiredVersion.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x335B6B88)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.system_update_rounded, color: Color(0xFFFACC15), size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Update Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    resolvedMessage,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Required version: $versionLabel',
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your version: ${ApiConfig.appVersion}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x335B6B88)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to update',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Open Google Play Store.',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '2. Search: Ride With Garv.',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '3. Tap Update.',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '4. Open the app again.',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthComplete});

  final VoidCallback onAuthComplete;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Welcome back rider' : 'Join Riders Communities';
    final subtitle = _isLogin
        ? 'Login to continue helping and getting help.'
        : 'Create your account to start posting in your city community.';
    final actionText = _isLogin ? 'Login' : 'Create account';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F7FF), Color(0xFFFDFEFF)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -50, right: -36, child: _FloatingBlob(size: 210, color: Color(0x2E1D4ED8))),
            const Positioned(top: 160, left: -34, child: _FloatingBlob(size: 140, color: Color(0x2414B8A6))),
            const Positioned(bottom: 90, right: -26, child: _FloatingBlob(size: 110, color: Color(0x24F97316))),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE8F1FF), Color(0xFFF2F7FF)],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A1D4ED8),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Rider-only secure community',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF22497F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF142C55),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF41597C),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x331D4ED8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AuthModeChip(
                                label: 'Login',
                                selected: _isLogin,
                                onTap: () => setState(() => _isLogin = true),
                              ),
                            ),
                            Expanded(
                              child: _AuthModeChip(
                                label: 'Signup',
                                selected: !_isLogin,
                                onTap: () => setState(() => _isLogin = false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x17000000),
                              blurRadius: 28,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            if (!_isLogin) ...[
                              TextField(
                                controller: _phoneController,
                                decoration: _fieldDecoration('Phone number', Icons.phone_rounded),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _emailController,
                              decoration: _fieldDecoration('Email', Icons.alternate_email_rounded),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: _fieldDecoration('Password', Icons.lock_outline_rounded),
                            ),
                            // Forgot password — hidden until flow is implemented.
                            // if (_isLogin)
                            //   Align(
                            //     alignment: Alignment.centerRight,
                            //     child: TextButton(
                            //       onPressed: () {},
                            //       child: const Text('Forgot password?'),
                            //     ),
                            //   ),
                            if (!_isLogin)
                              InkWell(
                                onTap: () {},
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x331D4ED8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 42,
                                        width: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF1FF),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Color(0xFF355E98),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Profile photo',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        const Color(0xFF22497F),
                                                  ),
                                            ),
                                            Text(
                                              'Tap to upload image',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xFF5A6F8C),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF4F6890),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _handlePrimaryAuthAction,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  actionText,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'or continue with',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                SizedBox.shrink(),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _SocialAuthButton(
                                    label: 'Google',
                                    icon: Icons.g_mobiledata_rounded,
                                    onPressed: () => _showComingSoonSheet(
                                      context,
                                      method: 'Google login',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SocialAuthButton(
                                    label: 'Phone OTP',
                                    icon: Icons.sms_outlined,
                                    onPressed: () => _showComingSoonSheet(
                                      context,
                                      method: 'OTP login',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isLogin
                            ? 'Use the email and password for your account.'
                            : 'Signup helps us keep the rider community trusted and safe.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5A6F8C),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF355E98)),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x331D4ED8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x331D4ED8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.4),
      ),
    );
  }

  void _showComingSoonSheet(
    BuildContext context, {
    required String method,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$method abhi coming soon hai',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Bhai ye feature hum jaldi live kar rahe hain. Abhi ke liye direct Email + Password se Login ya Signup karo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF435877),
                    ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Theek hai'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePrimaryAuthAction() {
    // Dev-mode shortcut so frontend screens can be built before backend auth.
    widget.onAuthComplete();
  }
}

class _AuthModeChip extends StatelessWidget {
  const _AuthModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF2D5B9E), Color(0xFF1D4ED8)],
                )
              : null,
          color: selected ? null : Colors.transparent,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x331D4ED8),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF335687),
          ),
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 11),
        side: const BorderSide(color: Color(0x331D4ED8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _PremiumOnboardingFlow(onContinue: onContinue);
  }
}

class _PremiumOnboardingFlow extends StatefulWidget {
  const _PremiumOnboardingFlow({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_PremiumOnboardingFlow> createState() => _PremiumOnboardingFlowState();
}

class _PremiumOnboardingFlowState extends State<_PremiumOnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _buttonPressed = false;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.groups_rounded,
      title: 'Riders helping riders',
      subtitle: 'Join a trusted community where delivery riders solve real problems together.',
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFF8E8)],
      chips: ['Delhi', 'Noida', 'Gurgaon'],
      avatarColors: [Color(0xFF0B1F3A), Color(0xFFF59E0B), Color(0xFF14B8A6)],
      lottieAsset: 'assets/lottie/community.json',
      imageAsset: 'assets/images/prelogin_onboarding_hero.png',
    ),
    _OnboardingData(
      icon: Icons.campaign_rounded,
      title: 'Post. Discuss. Resolve.',
      subtitle: 'Share issues with text or image and get practical comments from fellow riders.',
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFF3D1)],
      chips: ['Payout', 'Account Block', 'Safety'],
      avatarColors: [Color(0xFF0B1F3A), Color(0xFFB45309), Color(0xFFF59E0B)],
      lottieAsset: 'assets/lottie/discuss.json',
      imageAsset: 'assets/images/prelogin_discuss_hero.png',
    ),
    _OnboardingData(
      icon: Icons.bolt_rounded,
      title: 'Fast support, clear action',
      subtitle: 'Use smart forms, track updates, and get support that matters in field life.',
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFF8E8)],
      chips: ['Help Forms', 'EV Leads', 'Instant Updates'],
      avatarColors: [Color(0xFF14B8A6), Color(0xFF0B1F3A), Color(0xFFF59E0B)],
      lottieAsset: 'assets/lottie/support.json',
      imageAsset: 'assets/images/prelogin_support_hero.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNextOrContinue() async {
    setState(() {
      _buttonPressed = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _buttonPressed = false;
    });

    if (_currentPage == _pages.length - 1) {
      widget.onContinue();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  double _currentPageOffset(int index) {
    if (!_pageController.hasClients) return 0;
    final page = _pageController.page ?? _currentPage.toDouble();
    return (index - page).clamp(-1.2, 1.2);
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 700;
        final horizontalPadding = constraints.maxWidth < 360 ? 14.0 : 20.0;
        final maxContentWidth = constraints.maxWidth > 600 ? 560.0 : constraints.maxWidth;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFBF1), Color(0xFFFFF7DF)],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: -42,
                  left: -34,
                  child: _FloatingBlob(size: 180, color: Color(0x22F59E0B)),
                ),
                const Positioned(
                  top: 140,
                  right: -38,
                  child: _FloatingBlob(size: 135, color: Color(0x1A0B1F3A)),
                ),
                const Positioned(
                  bottom: 118,
                  left: -28,
                  child: _FloatingBlob(size: 116, color: Color(0x1AF4B400)),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          isCompactHeight ? 12 : 20,
                          horizontalPadding,
                          isCompactHeight ? 12 : 20,
                        ),
                        child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ride With Garv',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF0B1F3A),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onContinue,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFB45309),
                                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompactHeight ? 6 : 8),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (value) {
                              setState(() {
                                _currentPage = value;
                              });
                            },
                            itemCount: _pages.length,
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, child) {
                                  final offset = _currentPageOffset(index);
                                  return _AnimatedOnboardingCard(
                                    data: _pages[index],
                                    isActive: index == _currentPage,
                                    parallaxOffset: offset,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isCompactHeight ? 12 : 16),
                        _BottomGlassPanel(
                          currentPage: _currentPage,
                          totalPages: _pages.length,
                          isLastPage: isLastPage,
                          buttonPressed: _buttonPressed,
                          onNext: _goNextOrContinue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.chips,
    required this.avatarColors,
    required this.lottieAsset,
    this.imageAsset,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final List<String> chips;
  final List<Color> avatarColors;
  final String lottieAsset;
  final String? imageAsset;
}

class _AnimatedOnboardingCard extends StatelessWidget {
  const _AnimatedOnboardingCard({
    required this.data,
    required this.isActive,
    required this.parallaxOffset,
  });

  final _OnboardingData data;
  final bool isActive;
  final double parallaxOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 560;
        final compactWidth = constraints.maxWidth < 360;
        final iconBox = compactHeight ? 56.0 : 64.0;
        final iconSize = compactHeight ? 30.0 : 34.0;
        final titleStyle = compactWidth
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.headlineSmall;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: isActive ? 1.0 : 0.96),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Transform.translate(
            offset: Offset(parallaxOffset * -20, 0),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: compactHeight ? 4 : 8),
              padding: EdgeInsets.all(compactHeight ? 14 : 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: data.gradient,
                ),
                border: Border.all(color: const Color(0x33F4B400)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x180F172A),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: compactHeight ? 10 : 18),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      offset: isActive ? Offset.zero : const Offset(0, 0.1),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 260),
                        opacity: isActive ? 1 : 0.78,
                        child: _StyledHeadline(
                          text: data.title,
                          compact: compactWidth,
                          fallbackStyle: titleStyle,
                        ),
                      ),
                    ),
                    SizedBox(height: compactHeight ? 6 : 10),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      offset: isActive ? Offset.zero : const Offset(0, 0.12),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isActive ? 1 : 0.72,
                        child: _StyledSubtitle(text: data.subtitle),
                      ),
                    ),
                    SizedBox(height: compactHeight ? 8 : 12),
                    _OnboardingHeroVisual(
                      isActive: isActive,
                      icon: data.icon,
                      lottieAsset: data.lottieAsset,
                      imageAsset: data.imageAsset,
                      iconBox: iconBox,
                      iconSize: iconSize,
                    ),
                    SizedBox(height: compactHeight ? 10 : 16),
                    _AnimatedAvatarRow(
                      avatarColors: data.avatarColors,
                      isActive: isActive,
                      compact: compactHeight || compactWidth,
                    ),
                    SizedBox(height: compactHeight ? 12 : 18),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOutCubic,
                      offset: isActive ? Offset.zero : const Offset(0, 0.15),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isActive ? 1 : 0.7,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: data.chips
                              .map(
                                (chip) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3D1),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0x33F4B400)),
                                  ),
                                  child: Text(
                                    chip,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: const Color(0xFF0B1F3A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StyledHeadline extends StatelessWidget {
  const _StyledHeadline({
    required this.text,
    required this.compact,
    required this.fallbackStyle,
  });

  final String text;
  final bool compact;
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final base = fallbackStyle ??
        Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            );

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B1F3A), Color(0xFFB45309)],
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: base?.copyWith(
          color: Colors.white,
          letterSpacing: compact ? 0.1 : 0.2,
          height: 1.14,
          shadows: const [
            Shadow(
              color: Color(0x22000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledSubtitle extends StatelessWidget {
  const _StyledSubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF5B6B84),
          height: 1.35,
          letterSpacing: 0.2,
        );
    final highlight = body?.copyWith(
      color: const Color(0xFF0B1F3A),
      fontWeight: FontWeight.w900,
    );

    final lower = text.toLowerCase();
    final focusWords = ['community', 'riders', 'problems', 'support'];

    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      int? nearestIndex;
      String? nearestWord;
      for (final word in focusWords) {
        final idx = lower.indexOf(word, i);
        if (idx != -1 && (nearestIndex == null || idx < nearestIndex)) {
          nearestIndex = idx;
          nearestWord = word;
        }
      }

      if (nearestIndex == null || nearestWord == null) {
        spans.add(TextSpan(text: text.substring(i), style: body));
        break;
      }

      if (nearestIndex > i) {
        spans.add(TextSpan(text: text.substring(i, nearestIndex), style: body));
      }
      final end = nearestIndex + nearestWord.length;
      spans.add(TextSpan(text: text.substring(nearestIndex, end), style: highlight));
      i = end;
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }
}

class _OnboardingHeroVisual extends StatelessWidget {
  const _OnboardingHeroVisual({
    required this.isActive,
    required this.icon,
    required this.lottieAsset,
    required this.imageAsset,
    required this.iconBox,
    required this.iconSize,
  });

  final bool isActive;
  final IconData icon;
  final String lottieAsset;
  final String? imageAsset;
  final double iconBox;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final showWebFallback = kIsWeb;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: isActive ? Offset.zero : const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: isActive ? 1 : 0.75,
        child: imageAsset == null
            ? SizedBox(
                height: iconBox + 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showWebFallback)
                      _WebSafeHeroFallback(
                        icon: icon,
                        size: iconBox + 76,
                      )
                    else
                      Lottie.asset(
                        lottieAsset,
                        height: iconBox + 76,
                        fit: BoxFit.contain,
                        repeat: true,
                        animate: true,
                      ),
                    Positioned(
                      left: 10,
                      top: 8,
                      child: Container(
                        height: iconBox * 0.44,
                        width: iconBox * 0.44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                  child: Icon(
                    icon,
                    size: iconSize * 0.58,
                    color: const Color(0xFF0B1F3A),
                  ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x33F4B400)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220F172A),
                      blurRadius: 18,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: iconBox <= 56 ? 1.85 : 1.58,
                  child: Image.asset(
                    imageAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
      ),
    );
  }
}

class _WebSafeHeroFallback extends StatelessWidget {
  const _WebSafeHeroFallback({
    required this.icon,
    required this.size,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1FF59E0B), Color(0x1A0B1F3A)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Center(
          child: Icon(
            icon,
            color: const Color(0xFF0B1F3A),
            size: size * 0.36,
          ),
        ),
      ),
    );
  }
}

class _BottomGlassPanel extends StatelessWidget {
  const _BottomGlassPanel({
    required this.currentPage,
    required this.totalPages,
    required this.isLastPage,
    required this.buttonPressed,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final bool isLastPage;
  final bool buttonPressed;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44F4B400)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${currentPage + 1}/$totalPages',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0B1F3A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (isLastPage)
                Text(
                  'Almost done',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFB45309),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              final selected = index == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: selected ? 28 : 8,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEAD7A8),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutBack,
            scale: buttonPressed ? 0.96 : 1.0,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF172033),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isLastPage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                    key: ValueKey<bool>(isLastPage),
                  ),
                ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      isLastPage ? 'Enter Community' : 'Next',
                      key: ValueKey<bool>(isLastPage),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBlob extends StatefulWidget {
  const _FloatingBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_FloatingBlob> createState() => _FloatingBlobState();
}

class _FloatingBlobState extends State<_FloatingBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = (_controller.value - 0.5) * 14;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAvatarRow extends StatelessWidget {
  const _AnimatedAvatarRow({
    required this.avatarColors,
    required this.isActive,
    required this.compact,
  });

  final List<Color> avatarColors;
  final bool isActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 36.0 : 42.0;
    final rowHeight = compact ? 40.0 : 46.0;
    final spacing = compact ? 29.0 : 34.0;
    final rowWidth = ((avatarColors.length - 1) * spacing) + avatarSize;

    return Center(
      child: SizedBox(
        width: rowWidth,
        height: rowHeight,
        child: Stack(
          children: List.generate(avatarColors.length, (index) {
            final left = index * spacing;
            final delayShift = index.isEven ? -3.0 : 3.0;
            return AnimatedPositioned(
              duration: Duration(milliseconds: 350 + (index * 120)),
              curve: Curves.easeOutCubic,
              left: left,
              top: isActive ? delayShift : (compact ? 8 : 10),
              child: AnimatedScale(
                duration: Duration(milliseconds: 300 + (index * 100)),
                curve: Curves.easeOutBack,
                scale: isActive ? 1.0 : 0.86,
                child: _AvatarBubble(
                  color: avatarColors[index],
                  icon: index == 1 ? Icons.delivery_dining_rounded : Icons.person_rounded,
                  size: avatarSize,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.color,
    required this.icon,
    required this.size,
  });

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const CommunityFeedScreen(),
      const CreatePostScreen(),
      const AlertsScreen(),
      const ProfileScreen(),
    ];
    final titles = [
      'Community Feed',
      'Create Post',
      'Alerts',
      'Profile',
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titles[_currentIndex],
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF102A56),
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Delhi NCR riders solving real work problems',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF5D7190),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: IconButton(
                        tooltip: widget.isDarkMode ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                        onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
                        icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            height: 70,
            selectedIndex: _currentIndex,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            indicatorColor: const Color(0xFFE7EEFF),
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.groups_rounded),
                label: 'Community',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_box_rounded),
                label: 'Create',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_active_rounded),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: const [
        _CommunityOverviewCard(),
        SizedBox(height: 14),
        _FilterChipsRow(),
        SizedBox(height: 12),
        _DynamicUpdateCard(),
        SizedBox(height: 12),
        _PostCard(
          author: 'Rider, Delhi',
          problem: 'Facing payout delay from last 3 days. Anyone solved this before?',
          commentsCount: 8,
          isAnonymous: false,
          city: 'Delhi',
          company: 'Blinkit',
          tags: ['Payout', 'Urgent'],
        ),
        SizedBox(height: 12),
        _PostCard(
          author: 'Anonymous Rider',
          problem: 'Account got blocked after order cancellation issue. Need guidance.',
          commentsCount: 5,
          isAnonymous: true,
          city: 'Noida',
          company: 'Zepto',
          tags: ['Account Block', 'Help'],
        ),
      ],
    );
  }
}

class _CommunityOverviewCard extends StatelessWidget {
  const _CommunityOverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
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
                  'NCR Rider Pulse',
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
            'Live community health for Delhi, Noida and Gurgaon riders.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MiniStat(label: 'Active Riders', value: '1,240'),
              _MiniStat(label: 'Helped Today', value: '186'),
              _MiniStat(label: 'Avg Reply', value: '23 min'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF102A56))),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _PremiumFilterChip(icon: Icons.location_city_rounded, label: 'Delhi'),
        _PremiumFilterChip(icon: Icons.business_center_rounded, label: 'All companies'),
        _PremiumFilterChip(icon: Icons.translate_rounded, label: 'Hindi'),
        _PremiumFilterChip(icon: Icons.sell_rounded, label: 'Payout'),
      ],
    );
  }
}

class _PremiumFilterChip extends StatelessWidget {
  const _PremiumFilterChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F1D4ED8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DynamicUpdateCard extends StatelessWidget {
  const _DynamicUpdateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FF97316)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform update', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Today 7 PM: payment issue support live session.'),
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
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.author,
    required this.problem,
    required this.commentsCount,
    required this.isAnonymous,
    required this.city,
    required this.company,
    required this.tags,
  });

  final String author;
  final String problem;
  final int commentsCount;
  final bool isAnonymous;
  final String city;
  final String company;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x101D4ED8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAnonymous
                          ? const [Color(0xFF64748B), Color(0xFF334155)]
                          : const [Color(0xFF1D4ED8), Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isAnonymous ? Icons.visibility_off : Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '$company • Latest',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B7D99),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    city,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              problem,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    color: const Color(0xFF243B5A),
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(tag, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _PostActionPill(
                  icon: Icons.mode_comment_outlined,
                  label: '$commentsCount comments',
                ),
                const Spacer(),
                const _PostActionPill(
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Helpful',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostActionPill extends StatelessWidget {
  const _PostActionPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF476487)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  bool _anonymous = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share your issue', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                const TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your problem here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: 'Delhi',
                        items: const [
                          DropdownMenuItem(value: 'Delhi', child: Text('Delhi')),
                          DropdownMenuItem(value: 'Noida', child: Text('Noida')),
                          DropdownMenuItem(value: 'Gurgaon', child: Text('Gurgaon')),
                        ],
                        onChanged: (_) {},
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: 'Blinkit',
                        items: const [
                          DropdownMenuItem(value: 'Blinkit', child: Text('Blinkit')),
                          DropdownMenuItem(value: 'Zepto', child: Text('Zepto')),
                          DropdownMenuItem(value: 'Swiggy', child: Text('Swiggy')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (_) {},
                        decoration: const InputDecoration(labelText: 'Company'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                  title: const Text('Post as anonymous'),
                  subtitle: const Text('Admin can still view identity'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Add image'),
                    ),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Post now'),
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

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _AlertTile(
          title: 'New comment on your post',
          subtitle: 'Rider from Noida shared payout solution.',
          time: '2 min ago',
          icon: Icons.comment_rounded,
        ),
        SizedBox(height: 10),
        _AlertTile(
          title: 'Critical issue support',
          subtitle: 'Safety report marked high priority.',
          time: '17 min ago',
          icon: Icons.warning_amber_rounded,
        ),
        SizedBox(height: 10),
        _AlertTile(
          title: 'EV lead update',
          subtitle: 'Team will call you tomorrow morning.',
          time: '1 hr ago',
          icon: Icons.electric_bike_rounded,
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(time, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text('Rider Name'),
          subtitle: Text('Delhi • Company: Blinkit'),
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Common Problem Forms:\n• Payment/Earnings\n• Account Blocked\n• Safety/Accident',
            ),
          ),
        ),
        SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: Icon(Icons.electric_bike_rounded),
            title: Text('EV Section'),
            subtitle: Text('Explore 2-3 EV options and raise interest lead form'),
          ),
        ),
      ],
    );
  }
}

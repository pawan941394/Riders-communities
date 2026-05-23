import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/floating_blob.dart';
import '../config/api_config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthComplete});

  final ValueChanged<Map<String, dynamic>> onAuthComplete;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isSubmitting = false;
  static const String _apiAccessKey = ApiConfig.apiAccessKey;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;
  Uint8List? _profileImageBytes;

  String get _apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Welcome back rider' : 'Join Ride With Garv';
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
            colors: [Color(0xFFFFFBF1), Color(0xFFFFF7DF)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -50, right: -36, child: FloatingBlob(size: 210, color: Color(0x22F59E0B))),
            const Positioned(top: 160, left: -34, child: FloatingBlob(size: 140, color: Color(0x1A0B1F3A))),
            const Positioned(bottom: 90, right: -26, child: FloatingBlob(size: 110, color: Color(0x1AF4B400))),
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
                            colors: [Color(0xFF0B1F3A), Color(0xFFB45309)],
                          ),
                          border: Border.all(color: const Color(0x44F4B400)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x240F172A),
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
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B1F3A),
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
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF1).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x44F4B400)),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0x33F4B400)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x180F172A),
                              blurRadius: 28,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextField(
                              controller: _phoneController,
                              decoration: _fieldDecoration('Phone number', Icons.phone_rounded),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            if (!_isLogin) ...[
                              TextField(
                                controller: _fullNameController,
                                decoration: _fieldDecoration('Full name', Icons.badge_outlined),
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                decoration: _fieldDecoration('Email', Icons.alternate_email_rounded),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _referralCodeController,
                                decoration: _fieldDecoration(
                                  'Referral code (optional)',
                                  Icons.card_giftcard_rounded,
                                ),
                                textCapitalization: TextCapitalization.characters,
                              ),
                              const SizedBox(height: 12),
                            ],
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
                                onTap: _pickProfilePhoto,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBF1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x33F4B400),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 42,
                                        width: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3D1),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Color(0xFF0B1F3A),
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
                                                        const Color(0xFF0B1F3A),
                                                  ),
                                            ),
                                            Text(
                                              _profileImagePath != null || _profileImageBytes != null
                                                  ? 'Image selected'
                                                  : 'Tap to upload image',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xFF5B6B84),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF5B6B84),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _handlePrimaryAuthAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: const Color(0xFF172033),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Color(0xFF172033),
                                        ),
                                      )
                                    : Text(
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
                              color: const Color(0xFF5B6B84),
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
      prefixIcon: Icon(icon, color: const Color(0xFF0B1F3A)),
      filled: true,
      fillColor: const Color(0xFFFFFBF1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x33F4B400)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x33F4B400)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.4),
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
                      color: const Color(0xFFFFF3D1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      color: Color(0xFF0B1F3A),
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
                'Bhai ye feature hum jaldi live kar rahe hain. Abhi ke liye direct Phone + Password se login ya signup karo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B6B84),
                    ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF172033),
                  ),
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

  Future<void> _handlePrimaryAuthAction() async {
    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _phoneController.text.trim();
    final String referralCode = _referralCodeController.text.trim().toUpperCase();

    final String? validationError = _validateAuthInputs(
      isLogin: _isLogin,
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      hasProfilePhoto: _profileImagePath != null || _profileImageBytes != null,
    );
    if (validationError != null) {
      _showErrorModal(validationError);
      return;
    }

    setState(() => _isSubmitting = true);

    final Uri url = Uri.parse(
      _isLogin ? '$_apiBaseUrl/api/v1/auth/login' : '$_apiBaseUrl/api/v1/auth/signup',
    );

    try {
      late final http.Response response;
      if (_isLogin) {
        response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': _apiAccessKey,
          },
          body: jsonEncode({
            'phone_number': phone,
            'password': password,
          }),
        );
      } else {
        final request = http.MultipartRequest('POST', url)
          ..headers['X-API-Key'] = _apiAccessKey
          ..fields['full_name'] = fullName
          ..fields['email'] = email
          ..fields['password'] = password
          ..fields['phone_number'] = phone
          ..fields['preferred_language'] = 'en';
        if (referralCode.isNotEmpty) {
          request.fields['referral_code'] = referralCode;
        }

        if (kIsWeb && _profileImageBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_photo',
              _profileImageBytes!,
              filename: 'profile_photo.jpg',
            ),
          );
        } else if (_profileImagePath != null) {
          request.files.add(
            await http.MultipartFile.fromPath('profile_photo', _profileImagePath!),
          );
        }

        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      }

      final Map<String, dynamic> data = (response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{});

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String token = (data['access_token'] as String?) ?? '';
        if (token.isEmpty) {
          _showErrorModal('Access token missing in response.');
          return;
        }
        final Map<String, dynamic> profile =
            (data['profile'] is Map<String, dynamic>) ? data['profile'] as Map<String, dynamic> : {};
        _showSnack(
          (data['message'] as String?) ??
              (_isLogin ? 'Login successful.' : 'Signup successful.'),
        );
        widget.onAuthComplete({
          'access_token': token,
          'profile': profile,
          'phone_number': phone,
        });
        return;
      }

      _showErrorModal(_extractErrorMessage(data));
    } catch (_) {
      _showErrorModal(
        'Server not reachable. Make sure backend is running on $_apiBaseUrl.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorModal(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
              SizedBox(width: 8),
              Text('Action failed'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF0B1F3A),
      ),
    );
  }

  String _extractErrorMessage(Map<String, dynamic> data) {
    final dynamic detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final dynamic first = detail.first;
      if (first is Map<String, dynamic>) {
        final dynamic loc = first['loc'];
        final dynamic msg = first['msg'];
        if (loc is List && loc.isNotEmpty && msg is String && msg.isNotEmpty) {
          final String fieldName = loc.last
              .toString()
              .replaceAll('_', ' ')
              .replaceAllMapped(RegExp(r'(^| )([a-z])'), (m) => m.group(0)!.toUpperCase());
          return '$fieldName: $msg';
        }
        if (msg is String && msg.isNotEmpty) {
          return msg;
        }
      }
    }
    return 'Auth failed. Please try again.';
  }

  String? _validateAuthInputs({
    required bool isLogin,
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required bool hasProfilePhoto,
  }) {
    if (isLogin && phone.isEmpty) return 'Phone number is required.';
    if (isLogin && phone.length < 10) return 'Phone number must be at least 10 digits.';
    if (!isLogin && fullName.isEmpty) return 'Full name is required.';
    if (!isLogin && fullName.length < 2) return 'Full name must be at least 2 characters.';
    if (!isLogin && phone.isEmpty) return 'Phone number is required.';
    if (!isLogin && phone.length < 10) return 'Phone number must be at least 10 digits.';
    if (!isLogin && !hasProfilePhoto) return 'Profile photo is required.';
    if (!isLogin && email.isEmpty) return 'Email is required.';
    if (!isLogin && !email.contains('@')) return 'Please enter a valid email.';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 3) return 'Password must be at least 3 characters.';
    return null;
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (selected == null) return;

    if (kIsWeb) {
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImageBytes = bytes;
        _profileImagePath = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _profileImagePath = selected.path;
      _profileImageBytes = null;
    });
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
                  colors: [Color(0xFF0B1F3A), Color(0xFF1F3555)],
                )
              : null,
          color: selected ? null : Colors.transparent,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x220F172A),
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
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF0B1F3A),
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
        side: const BorderSide(color: Color(0x33F4B400)),
        foregroundColor: const Color(0xFF0B1F3A),
        backgroundColor: const Color(0xFFFFFBF1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

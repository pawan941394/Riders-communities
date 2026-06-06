import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

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
  bool _useOtpFlow = true;
  bool _isSubmitting = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _otpNeedsSignup = false;
  bool _otpSdkInitialized = false;
  String _otpReqId = '';
  static const String _apiAccessKey = ApiConfig.apiAccessKey;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _riderIdController = TextEditingController();
  final TextEditingController _riderCompanyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;
  Uint8List? _profileImageBytes;

  String get _apiBaseUrl {
    return ApiConfig.apiBaseUrl;
  }

  bool get _isOtpBusy => _isSendingOtp || _isVerifyingOtp || _isResendingOtp;

  @override
  void initState() {
    super.initState();
    _initOtpSdkIfPossible();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _riderIdController.dispose();
    _riderCompanyController.dispose();
    _cityController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _useOtpFlow
        ? (_otpNeedsSignup ? 'Complete OTP signup' : 'Login with OTP')
        : (_isLogin ? 'Welcome back rider' : 'Join Ride With Garv');
    final subtitle = _useOtpFlow
        ? (_otpNeedsSignup
              ? 'OTP verified hai, ab signup details fill karo.'
              : 'Phone number daalo, OTP verify karo, aur direct login.')
        : (_isLogin
              ? 'Login to continue helping and getting help.'
              : 'Create your account to start posting in your city community.');
    final actionText = _useOtpFlow
        ? (_otpNeedsSignup
              ? 'Complete signup'
              : (_otpSent ? 'Verify OTP' : 'Send OTP'))
        : (_isLogin ? 'Login' : 'Create account');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -50,
              right: -36,
              child: FloatingBlob(size: 210, color: Color(0x11000000)),
            ),
            const Positioned(
              top: 160,
              left: -34,
              child: FloatingBlob(size: 140, color: Color(0x1A0B1F3A)),
            ),
            const Positioned(
              bottom: 90,
              right: -26,
              child: FloatingBlob(size: 110, color: Color(0x0F000000)),
            ),
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
                            colors: [Color(0xFF0B1F3A), Color(0xFF111827)],
                          ),
                          border: Border.all(color: const Color(0x1FFFFFFF)),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFFE2E8F0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!_useOtpFlow) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x1F000000)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _AuthModeChip(
                                  label: 'Login',
                                  selected: _isLogin,
                                  onTap: () => _setLoginMode(true),
                                ),
                              ),
                              Expanded(
                                child: _AuthModeChip(
                                  label: 'Signup',
                                  selected: !_isLogin,
                                  onTap: () => _setLoginMode(false),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0x1F000000)),
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
                              decoration: _fieldDecoration(
                                'Phone number',
                                Icons.phone_rounded,
                              ).copyWith(prefixText: '+91 ', counterText: ''),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 10,
                            ),
                            const SizedBox(height: 12),
                            if (_useOtpFlow && _otpSent) ...[
                              TextField(
                                controller: _otpController,
                                decoration: _fieldDecoration(
                                  'OTP',
                                  Icons.lock_clock_rounded,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if ((_useOtpFlow && !_isLogin && _otpNeedsSignup) ||
                                (!_useOtpFlow && !_isLogin)) ...[
                              TextField(
                                controller: _fullNameController,
                                decoration: _fieldDecoration(
                                  'Full name',
                                  Icons.badge_outlined,
                                ),
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                decoration: _fieldDecoration(
                                  'Email',
                                  Icons.alternate_email_rounded,
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              if (_useOtpFlow) ...[
                                TextField(
                                  controller: _riderCompanyController,
                                  decoration: _fieldDecoration(
                                    'Company (optional)',
                                    Icons.business_rounded,
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _riderIdController,
                                  decoration: _fieldDecoration(
                                    'Rider ID (optional)',
                                    Icons.badge_rounded,
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _cityController,
                                  decoration: _fieldDecoration(
                                    'City (optional)',
                                    Icons.location_city_rounded,
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: _referralCodeController,
                                decoration: _fieldDecoration(
                                  'Referral code (optional)',
                                  Icons.card_giftcard_rounded,
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (!_useOtpFlow)
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: _fieldDecoration(
                                  'Password',
                                  Icons.lock_outline_rounded,
                                ),
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
                            if (!_useOtpFlow && !_isLogin)
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x1F000000),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 42,
                                        width: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
                                                    color: const Color(
                                                      0xFF0B1F3A,
                                                    ),
                                                  ),
                                            ),
                                            Text(
                                              _profileImagePath != null ||
                                                      _profileImageBytes != null
                                                  ? 'Image selected'
                                                  : 'Tap to upload image',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: const Color(
                                                      0xFF5B6B84,
                                                    ),
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
                                onPressed: (_isSubmitting || _isOtpBusy)
                                    ? null
                                    : _handlePrimaryAuthAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B1F3A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: (_isSubmitting || _isSendingOtp)
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_useOtpFlow && _otpSent)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _isOtpBusy
                                      ? null
                                      : _handleResendOtp,
                                  icon: _isResendingOtp
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    _isResendingOtp
                                        ? 'Resending...'
                                        : 'Resend OTP',
                                  ),
                                ),
                              ),
                            if (!_useOtpFlow) ...[
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'or continue with',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _useOtpFlow
                            ? 'Phone number daalo, OTP verify karo. Naya user hoga to signup fields auto aa jayenge.'
                            : (_isLogin
                                  ? 'Use the email and password for your account.'
                                  : 'Signup helps us keep the rider community trusted and safe.'),
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x1F000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x1F000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0B1F3A), width: 1.4),
      ),
    );
  }

  Future<void> _initOtpSdkIfPossible() async {
    if (_otpSdkInitialized) return;
    String widgetId = ApiConfig.sendOtpWidgetId.trim();
    String authToken = ApiConfig.sendOtpAuthToken.trim();
    if (widgetId.isEmpty || authToken.isEmpty) {
      final Map<String, String>? runtime = await _fetchOtpRuntimeConfig();
      if (runtime != null) {
        widgetId = runtime['widget_id'] ?? '';
        authToken = runtime['auth_token'] ?? '';
      }
    }
    if (widgetId.isEmpty || authToken.isEmpty) {
      return;
    }
    try {
      OTPWidget.initializeWidget(widgetId, authToken);
      _otpSdkInitialized = true;
    } catch (_) {
      _otpSdkInitialized = false;
    }
  }

  Future<Map<String, String>?> _fetchOtpRuntimeConfig() async {
    try {
      final http.Response response = await http.get(
        Uri.parse('$_apiBaseUrl/api/v1/auth/otp/config'),
        headers: <String, String>{'X-API-Key': _apiAccessKey},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final Map<String, dynamic> data = response.body.isNotEmpty
          ? (jsonDecode(response.body) as Map<String, dynamic>)
          : <String, dynamic>{};
      final bool enabled = (data['enabled'] as bool?) ?? false;
      if (!enabled) {
        return null;
      }
      final String widgetId = ('${data['widget_id'] ?? ''}').trim();
      final String authToken = ('${data['auth_token'] ?? ''}').trim();
      if (widgetId.isEmpty || authToken.isEmpty) {
        return null;
      }
      return <String, String>{'widget_id': widgetId, 'auth_token': authToken};
    } catch (_) {
      return null;
    }
  }

  void _resetOtpJourney() {
    _otpSent = false;
    _otpVerified = false;
    _otpNeedsSignup = false;
    _otpReqId = '';
    _otpController.clear();
  }

  void _setLoginMode(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _resetOtpJourney();
    });
  }

  void _setAuthMethod(bool useOtpFlow) {
    setState(() {
      _useOtpFlow = useOtpFlow;
      _resetOtpJourney();
      if (useOtpFlow) {
        _isLogin = true;
      }
    });
  }

  String _normalizeLocalPhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('91') && digits.length >= 12) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _toSendOtpIdentifier(String localPhone) {
    final String digits = _normalizeLocalPhone(localPhone);
    if (digits.length == 10) return '91$digits';
    return digits;
  }

  String _extractReqId(dynamic response) {
    if (response is String) {
      final String raw = response.trim();
      // Some providers return request id directly as plain string.
      if (raw.isNotEmpty && !raw.contains(' ') && raw.length >= 12) {
        return raw;
      }
    }

    final Map<String, dynamic>? map = _asJsonMap(response);
    if (map != null) {
      final List<String> keys = <String>[
        'reqId',
        'req_id',
        'request_id',
        'requestId',
        'reference_id',
        'referenceId',
      ];
      for (final String key in keys) {
        final dynamic value = map[key];
        if (value != null && '$value'.trim().isNotEmpty) {
          return '$value'.trim();
        }
      }
      final String messageAsId = ('${map['message'] ?? ''}').trim();
      if (messageAsId.isNotEmpty &&
          !messageAsId.contains(' ') &&
          messageAsId.length >= 12) {
        return messageAsId;
      }
      final Map<String, dynamic>? data = _asJsonMap(map['data']);
      if (data != null) {
        for (final String key in keys) {
          final dynamic value = data[key];
          if (value != null && '$value'.trim().isNotEmpty) {
            return '$value'.trim();
          }
        }
        final String nestedMessageAsId = ('${data['message'] ?? ''}').trim();
        if (nestedMessageAsId.isNotEmpty &&
            !nestedMessageAsId.contains(' ') &&
            nestedMessageAsId.length >= 12) {
          return nestedMessageAsId;
        }
      }
    }
    return '';
  }

  bool _isOtpSuccess(dynamic response) {
    final String flatResponse =
        (response is String
                ? response
                : jsonEncode(_asJsonMap(response) ?? <String, dynamic>{}))
            .toLowerCase()
            .trim();
    if (flatResponse.contains('already verified') ||
        flatResponse.contains('otp already verified')) {
      return true;
    }
    if (response is String) {
      final String raw = response.toLowerCase().trim();
      if (raw.isEmpty) return false;
      final bool hasPositive =
          raw.contains('success') ||
          raw.contains('verified') ||
          raw.contains('otp verified');
      final bool hasNegative =
          raw.contains('fail') ||
          raw.contains('invalid') ||
          raw.contains('wrong') ||
          raw.contains('expired') ||
          raw.contains('blocked') ||
          raw.contains('error');
      if (hasPositive && !hasNegative) return true;
    }

    final Map<String, dynamic>? map = _asJsonMap(response);
    if (map != null) {
      final String status = ('${map['status'] ?? map['statusCode'] ?? ''}')
          .toLowerCase()
          .trim();
      final String message =
          ('${map['message'] ?? map['detail'] ?? map['error'] ?? ''}')
              .toLowerCase()
              .trim();
      final dynamic success = map['success'];
      final dynamic verified =
          map['verified'] ?? map['is_verified'] ?? map['isVerified'];
      if (success == true) return true;
      if (verified == true) return true;
      if (status == 'success' || status == 'ok' || status == '200') return true;
      if (message.contains('verified') || message.contains('success'))
        return true;
      final dynamic dataRaw = map['data'];
      final Map<String, dynamic>? data = _asJsonMap(dataRaw);
      if (data != null) {
        final dynamic dataSuccess = data['success'];
        final dynamic dataVerified =
            data['verified'] ?? data['is_verified'] ?? data['isVerified'];
        if (dataSuccess == true) return true;
        if (dataVerified == true) return true;
        final String dataMessage =
            ('${data['message'] ?? data['detail'] ?? data['error'] ?? ''}')
                .toLowerCase()
                .trim();
        if (dataMessage.contains('verified') || dataMessage.contains('success'))
          return true;
      }
    }
    return false;
  }

  bool _isOtpExplicitFailure(dynamic response) {
    String raw = '';
    if (response is String) {
      raw = response.toLowerCase().trim();
    } else {
      final Map<String, dynamic>? map = _asJsonMap(response);
      if (map != null) {
        raw = jsonEncode(map).toLowerCase();
      }
    }
    if (raw.isEmpty) return false;
    const List<String> failWords = <String>[
      'invalid',
      'wrong',
      'incorrect',
      'expired',
      'blocked',
      'ipblocked',
      'too many',
      'attempt',
      'fail',
      'failed',
      'error',
      'denied',
      'mismatch',
    ];
    return failWords.any(raw.contains);
  }

  String _otpFailureMessage(dynamic response) {
    final String flat = ('$response').toLowerCase();
    if (flat.contains('ipblocked') || flat.contains('ip blocked')) {
      return 'Aaj OTP limit exceed ho gayi hai. 24 hours baad phir try karein.';
    }
    if (response is String) {
      final String msg = response.trim();
      if (msg.isNotEmpty) return msg;
    }
    final Map<String, dynamic>? map = _asJsonMap(response);
    if (map != null) {
      final String msg =
          ('${map['message'] ?? map['detail'] ?? map['error'] ?? ''}').trim();
      if (msg.isNotEmpty) return msg;
      final Map<String, dynamic>? data = _asJsonMap(map['data']);
      if (data != null) {
        final String nested =
            ('${data['message'] ?? data['detail'] ?? data['error'] ?? ''}')
                .trim();
        if (nested.isNotEmpty) return nested;
      }
    }
    return 'OTP verification failed. Please check and retry.';
  }

  Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry<String, dynamic>('$k', v),
      );
    }
    if (value is String) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map<String, dynamic>(
            (dynamic k, dynamic v) => MapEntry<String, dynamic>('$k', v),
          );
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response response = await http.post(
      Uri.parse('$_apiBaseUrl$path'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-API-Key': _apiAccessKey,
      },
      body: jsonEncode(body),
    );
    final Map<String, dynamic> data = response.body.isNotEmpty
        ? (jsonDecode(response.body) as Map<String, dynamic>)
        : <String, dynamic>{};
    return <String, dynamic>{'status': response.statusCode, 'data': data};
  }

  Future<void> _handleSendOtp() async {
    final String phone = _normalizeLocalPhone(_phoneController.text.trim());
    if (phone.length < 10) {
      _showErrorModal('Please enter a valid 10-digit phone number.');
      return;
    }
    if (_isOtpBusy) return;
    setState(() => _isSendingOtp = true);
    try {
      await _initOtpSdkIfPossible();
      if (!_otpSdkInitialized) {
        _showErrorModal(
          'OTP config not available. Please check server OTP env setup.',
        );
        return;
      }

      final Map<String, dynamic> precheck = await _postJson(
        '/api/v1/auth/otp/precheck',
        <String, dynamic>{'phone_number': phone},
      );
      final int status = (precheck['status'] as int?) ?? 500;
      final Map<String, dynamic> precheckData =
          (precheck['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (status < 200 || status >= 300) {
        _showErrorModal(_extractErrorMessage(precheckData));
        return;
      }
      final bool userExists = (precheckData['user_exists'] as bool?) ?? false;
      _otpNeedsSignup =
          (precheckData['signup_required'] as bool?) ?? !userExists;

      final String identifier = _toSendOtpIdentifier(phone);
      final dynamic otpSendResponse = await OTPWidget.sendOTP(<String, dynamic>{
        'identifier': identifier,
      });
      final String reqId = _extractReqId(otpSendResponse);
      if (reqId.isEmpty) {
        final Map<String, dynamic>? parsed = _asJsonMap(otpSendResponse);
        final String msg = ('${parsed?['message'] ?? ''}').trim();
        final String flat = ('${msg.isNotEmpty ? msg : otpSendResponse}')
            .toLowerCase();
        if (flat.contains('ipblocked') || flat.contains('ip blocked')) {
          _showErrorModal(
            'Aaj OTP limit exceed ho gayi hai. 24 hours baad phir try karein.',
          );
          return;
        }
        _showErrorModal(
          msg.isNotEmpty
              ? 'OTP request id missing from provider response: $msg'
              : 'OTP request ID not returned. Please try again.',
        );
        return;
      }
      setState(() {
        _otpReqId = reqId;
        _otpSent = true;
        _otpVerified = false;
      });
      _showSnack(
        'OTP sent successfully. SMS aane me 20-60 sec lag sakte hain.',
      );
    } catch (_) {
      _showErrorModal('Could not send OTP right now.');
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_otpReqId.isEmpty) {
      await _handleSendOtp();
      return;
    }
    if (_isOtpBusy) return;
    setState(() => _isResendingOtp = true);
    try {
      final dynamic retryResponse = await OTPWidget.retryOTP(<String, dynamic>{
        'reqId': _otpReqId,
        'retryChannel': 11, // SMS
      });
      final String nextReqId = _extractReqId(retryResponse);
      if (nextReqId.isNotEmpty) {
        _otpReqId = nextReqId;
      }
      _showSnack('OTP resend request sent.');
    } catch (_) {
      _showErrorModal('Could not resend OTP. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResendingOtp = false);
      }
    }
  }

  Future<void> _handleVerifyOtpAndContinue() async {
    final String otp = _otpController.text.trim();
    final String phone = _normalizeLocalPhone(_phoneController.text.trim());
    if (phone.length < 10) {
      _showErrorModal('Please enter a valid phone number.');
      return;
    }
    if (_otpReqId.isEmpty) {
      _showErrorModal('Please send OTP first.');
      return;
    }
    if (otp.length < 4) {
      _showErrorModal('Please enter a valid OTP.');
      return;
    }
    if (_isOtpBusy) return;
    setState(() => _isVerifyingOtp = true);
    try {
      final dynamic otpVerifyResponse = await OTPWidget.verifyOTP(
        <String, dynamic>{'reqId': _otpReqId, 'otp': otp},
      );
      final bool explicitFailure = _isOtpExplicitFailure(otpVerifyResponse);
      final bool parsedSuccess = _isOtpSuccess(otpVerifyResponse);
      if (explicitFailure && !parsedSuccess) {
        _showErrorModal(_otpFailureMessage(otpVerifyResponse));
        return;
      }

      setState(() => _otpVerified = true);
      final Map<String, dynamic> complete = await _postJson(
        '/api/v1/auth/otp/complete-login',
        <String, dynamic>{
          'phone_number': phone,
          'otp_verified': true,
          'verification_ref': _otpReqId,
        },
      );
      final int status = (complete['status'] as int?) ?? 500;
      final Map<String, dynamic> data =
          (complete['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (status < 200 || status >= 300) {
        _showErrorModal(_extractErrorMessage(data));
        return;
      }

      final bool signupRequired = (data['signup_required'] as bool?) ?? false;
      if (signupRequired) {
        setState(() {
          _isLogin = false;
          _otpNeedsSignup = true;
        });
        _showSnack('OTP verified. Please complete signup.');
        return;
      }

      final String token = ('${data['access_token'] ?? ''}').trim();
      if (token.isEmpty) {
        _showErrorModal('Access token missing in response.');
        return;
      }
      final Map<String, dynamic> profile =
          (data['profile'] is Map<String, dynamic>)
          ? data['profile'] as Map<String, dynamic>
          : <String, dynamic>{};
      widget.onAuthComplete(<String, dynamic>{
        'access_token': token,
        'profile': profile,
        'phone_number': phone,
      });
    } catch (error) {
      final String msg = error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();
      _showErrorModal(
        msg.isEmpty ? 'Could not verify OTP right now.' : 'Verify error: $msg',
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  Future<void> _handleOtpSignup() async {
    final String phone = _normalizeLocalPhone(_phoneController.text.trim());
    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String referralCode = _referralCodeController.text
        .trim()
        .toUpperCase();
    if (!_otpVerified) {
      _showErrorModal('Please verify OTP first.');
      return;
    }
    if (fullName.length < 2) {
      _showErrorModal('Full name must be at least 2 characters.');
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      _showErrorModal('Please enter a valid email.');
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> res =
          await _postJson('/api/v1/auth/otp/register', <String, dynamic>{
            'phone_number': phone,
            'full_name': fullName,
            'email': email.isEmpty ? null : email,
            'rider_id': _riderIdController.text.trim().isEmpty
                ? null
                : _riderIdController.text.trim(),
            'rider_company': _riderCompanyController.text.trim().isEmpty
                ? null
                : _riderCompanyController.text.trim(),
            'city': _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            'preferred_language': 'en',
            'referral_code': referralCode.isEmpty ? null : referralCode,
            'otp_verified': true,
            'verification_ref': _otpReqId,
          });
      final int status = (res['status'] as int?) ?? 500;
      final Map<String, dynamic> data =
          (res['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (status < 200 || status >= 300) {
        _showErrorModal(_extractErrorMessage(data));
        return;
      }
      final String token = ('${data['access_token'] ?? ''}').trim();
      if (token.isEmpty) {
        _showErrorModal('Access token missing in response.');
        return;
      }
      final Map<String, dynamic> profile =
          (data['profile'] is Map<String, dynamic>)
          ? data['profile'] as Map<String, dynamic>
          : <String, dynamic>{};
      widget.onAuthComplete(<String, dynamic>{
        'access_token': token,
        'profile': profile,
        'phone_number': phone,
      });
    } catch (_) {
      _showErrorModal('Could not complete signup.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showComingSoonSheet(BuildContext context, {required String method}) {
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
                      color: const Color(0xFFF8FAFC),
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
                    backgroundColor: const Color(0xFF0B1F3A),
                    foregroundColor: Colors.white,
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
    if (_useOtpFlow) {
      if (_isLogin) {
        if (_otpSent) {
          await _handleVerifyOtpAndContinue();
        } else {
          await _handleSendOtp();
        }
      } else {
        await _handleOtpSignup();
      }
      return;
    }

    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _phoneController.text.trim();
    final String referralCode = _referralCodeController.text
        .trim()
        .toUpperCase();

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
      _isLogin
          ? '$_apiBaseUrl/api/v1/auth/login'
          : '$_apiBaseUrl/api/v1/auth/signup',
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
          body: jsonEncode({'phone_number': phone, 'password': password}),
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
            await http.MultipartFile.fromPath(
              'profile_photo',
              _profileImagePath!,
            ),
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
            (data['profile'] is Map<String, dynamic>)
            ? data['profile'] as Map<String, dynamic>
            : {};
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
        backgroundColor: isError
            ? const Color(0xFFB91C1C)
            : const Color(0xFF0B1F3A),
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
              .replaceAllMapped(
                RegExp(r'(^| )([a-z])'),
                (m) => m.group(0)!.toUpperCase(),
              );
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
    if (isLogin && phone.length < 10)
      return 'Phone number must be at least 10 digits.';
    if (!isLogin && fullName.isEmpty) return 'Full name is required.';
    if (!isLogin && fullName.length < 2)
      return 'Full name must be at least 2 characters.';
    if (!isLogin && phone.isEmpty) return 'Phone number is required.';
    if (!isLogin && phone.length < 10)
      return 'Phone number must be at least 10 digits.';
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
        side: const BorderSide(color: Color(0x1F000000)),
        foregroundColor: const Color(0xFF0B1F3A),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

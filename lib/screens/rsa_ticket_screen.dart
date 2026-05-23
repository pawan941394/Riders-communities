import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

class RsaTicketItem {
  const RsaTicketItem({
    required this.id,
    required this.region,
    required this.issue,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.assignedToName,
    required this.adminNotes,
    required this.latestHistoryStatus,
    required this.latestHistoryNote,
    required this.gpsLatitude,
    required this.gpsLongitude,
  });

  final int id;
  final String region;
  final String issue;
  final String description;
  final String status;
  final String createdAt;
  final String assignedToName;
  final String adminNotes;
  final String latestHistoryStatus;
  final String latestHistoryNote;
  final double? gpsLatitude;
  final double? gpsLongitude;

  bool get isActive => status != 'resolved' && status != 'cancelled';
  bool get hasLocation => gpsLatitude != null && gpsLongitude != null;

  String get displayStatus {
    final String historyStatus = latestHistoryStatus.isEmpty ? status : latestHistoryStatus;
    switch (historyStatus) {
      case 'created':
        return 'Created';
      case 'status_changed':
        return 'Status changed';
      case 'note_added':
        return 'Note added';
      case 'assigned':
        return 'Assigned';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In progress';
      case 'new':
        return 'New';
      default:
        return historyStatus.isEmpty ? 'New' : historyStatus.replaceAll('_', ' ');
    }
  }

  String get solutionText {
    if (latestHistoryNote.isNotEmpty) return latestHistoryNote;
    if (adminNotes.isNotEmpty) return adminNotes;
    return 'Awaiting support update.';
  }

  factory RsaTicketItem.fromJson(Map<String, dynamic> json) {
    String latestHistoryStatus = '';
    String latestHistoryNote = '';
    final dynamic rawHistory = json['history'];
    if (rawHistory is List<dynamic> && rawHistory.isNotEmpty) {
      final Map<String, dynamic>? latestHistory = _safeMap(rawHistory.first);
      if (latestHistory != null) {
        latestHistoryStatus = _safeText(latestHistory['status']);
        latestHistoryNote = _safeText(latestHistory['note']);
      }
    }
    return RsaTicketItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id'] ?? '0'}') ?? 0,
      region: _safeText(json['region']),
      issue: _safeText(json['issue']),
      description: _safeText(json['description']),
      status: _safeText(json['status']).isEmpty ? 'new' : _safeText(json['status']),
      createdAt: _safeText(json['created_at']),
      assignedToName: _safeText(json['assigned_to_name']),
      adminNotes: _safeText(json['admin_notes']),
      latestHistoryStatus: latestHistoryStatus,
      latestHistoryNote: latestHistoryNote,
      gpsLatitude: _safeDouble(json['gps_latitude']),
      gpsLongitude: _safeDouble(json['gps_longitude']),
    );
  }
}

String _safeText(dynamic value) {
  if (value == null) return '';
  return '$value'.trim();
}

Map<String, dynamic>? _safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic val) => MapEntry<String, dynamic>('$key', val),
    );
  }
  return null;
}

double? _safeDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

Future<void> openRsaTicketMap(RsaTicketItem ticket) async {
  if (!ticket.hasLocation) return;
  final String url =
      'https://www.google.com/maps/search/?api=1&query=${ticket.gpsLatitude},${ticket.gpsLongitude}';
  await launchUrlString(url, mode: LaunchMode.externalApplication);
}

class RsaTicketScreen extends StatefulWidget {
  const RsaTicketScreen({
    super.key,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
    this.initialPhone = '',
  });

  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;
  final String initialPhone;

  @override
  State<RsaTicketScreen> createState() => _RsaTicketScreenState();
}

class _RsaTicketScreenState extends State<RsaTicketScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _alternatePhoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _showGuide = false;
  bool _loadingProfilePhone = false;
  bool _gpsCaptured = false;
  bool _detectingGps = false;
  bool _submittingTicket = false;
  bool _loadingTickets = false;
  String? _ticketsError;
  int? _submittedTicketId;
  List<RsaTicketItem> _tickets = <RsaTicketItem>[];
  String _profileName = '';
  String _profileRiderId = '';
  String _profilePhone = '';
  String _vehicleCompany = '';
  String _vehicleModel = '';
  String _vehicleNumber = '';
  double? _gpsLatitude;
  double? _gpsLongitude;
  String? _gpsError;
  int _currentStep = 0;
  int _selectedTicketTab = 1;
  String _selectedRegion = 'Region chune';
  String _selectedIssue = 'Samasya chune';
  String _verifiedPhone = '';

  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _safeText(widget.initialPhone);
    _loadRsaProfileSummary();
    _loadRsaTickets();
    if (_phoneController.text.trim().isEmpty) {
      _loadProfilePhone();
    }
  }

  Map<String, String> get _headers {
    return <String, String>{
      'X-API-Key': widget.apiAccessKey,
      'Authorization': 'Bearer ${widget.accessToken.trim()}',
    };
  }

  Future<void> _loadRsaProfileSummary() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    try {
      final http.Response profileResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/auth/me'),
        headers: _headers,
      );
      if (profileResponse.statusCode >= 200 && profileResponse.statusCode < 300) {
        final dynamic decoded = jsonDecode(profileResponse.body);
        final Map<String, dynamic>? root = _safeMap(decoded);
        final Map<String, dynamic>? profile = _safeMap(root?['profile']);
        if (profile != null) {
          final String phone =
              _safeText(profile['phone_number'] ?? profile['phone'] ?? profile['mobile_number']);
          if (mounted) {
            setState(() {
              _profileName = _safeText(profile['full_name'] ?? profile['username']);
              _profileRiderId = _safeText(profile['rider_id']);
              _profilePhone = phone;
              if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
                _phoneController.text = phone;
              }
            });
          }
        }
      }

      final http.Response vehicleResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/vehicle/me'),
        headers: _headers,
      );
      if (vehicleResponse.statusCode >= 200 && vehicleResponse.statusCode < 300) {
        final dynamic decoded = jsonDecode(vehicleResponse.body);
        final Map<String, dynamic>? root = _safeMap(decoded);
        final Map<String, dynamic>? vehicle = _safeMap(root?['vehicle']);
        if (vehicle != null) {
          if (mounted) {
            setState(() {
              _vehicleCompany = _safeText(vehicle['company_name']);
              _vehicleModel = _safeText(vehicle['model_name']);
              _vehicleNumber = _safeText(vehicle['registration_number']);
            });
          }
        }
      }
    } catch (_) {
      // Keep summary fallback values if profile/vehicle lookup fails.
    }
  }

  Future<void> _loadRsaTickets() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    if (mounted) {
      setState(() {
        _loadingTickets = true;
        _ticketsError = null;
      });
    }
    try {
      final http.Response response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/rsa/tickets?limit=50'),
        headers: _headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Could not load RSA tickets.';
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            message = '${decoded['detail']}';
          }
        } catch (_) {}
        throw Exception(message);
      }
      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic>? root = _safeMap(decoded);
      final dynamic rawItems = root?['items'];
      final List<RsaTicketItem> rows = <RsaTicketItem>[];
      if (rawItems is List<dynamic>) {
        for (final dynamic row in rawItems) {
          final Map<String, dynamic>? item = _safeMap(row);
          if (item != null) {
            rows.add(RsaTicketItem.fromJson(item));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _tickets = rows;
        _ticketsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketsError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loadingTickets = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhone() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    setState(() => _loadingProfilePhone = true);
    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/auth/me');
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic>? root = _safeMap(decoded);
      final Map<String, dynamic>? profileRaw = _safeMap(root?['profile']);
      if (profileRaw == null) return;
      final String phone =
          _safeText(profileRaw['phone_number'] ?? profileRaw['phone'] ?? profileRaw['mobile_number']);
      if (phone.isEmpty || !mounted || _phoneController.text.trim().isNotEmpty) return;
      setState(() => _phoneController.text = phone);
    } catch (_) {
      // Keep the field editable if profile lookup fails.
    } finally {
      if (mounted) {
        setState(() => _loadingProfilePhone = false);
      }
    }
  }

  void _verifyRider() {
    final String phone = _phoneController.text.trim();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Please enter a valid 10-digit mobile number.', 'कृपया सही 10 अंकों का मोबाइल नंबर दर्ज करें।'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    setState(() {
      _verifiedPhone = phone;
      _currentStep = 1;
      _selectedTicketTab = 1;
    });
    _loadRsaTickets();
  }

  Future<void> _captureLiveGps() async {
    if (_detectingGps) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _detectingGps = true;
      _gpsError = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _gpsCaptured = false;
          _gpsError = 'Please turn on location services and try again.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _gpsCaptured = false;
          _gpsError = 'Location permission denied.';
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _gpsCaptured = false;
          _gpsError = 'Location permission is blocked. Enable it from app settings.';
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _gpsLatitude = position.latitude;
        _gpsLongitude = position.longitude;
        _gpsCaptured = true;
        _gpsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsCaptured = false;
        _gpsError = 'Could not detect live location. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _detectingGps = false);
      }
    }
  }

  Future<void> _submitRsaTicket() async {
    if (_submittingTicket) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final String callingPhone = _alternatePhoneController.text.trim();
    final String description = _descriptionController.text.trim();
    final String primaryPhone =
        (_verifiedPhone.isEmpty ? _phoneController.text : _verifiedPhone).trim();
    final String alternatePhoneForApi = callingPhone.isEmpty ? primaryPhone : callingPhone;

    if (primaryPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please verify your registered mobile number first.', 'कृपया पहले अपना रजिस्टर्ड मोबाइल नंबर वेरिफाई करें।'))),
      );
      return;
    }
    if (callingPhone.isNotEmpty && callingPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please enter a valid 10-digit alternative mobile number.', 'कृपया सही 10 अंकों का वैकल्पिक मोबाइल नंबर दर्ज करें।'))),
      );
      return;
    }
    if (_selectedRegion == 'Region chune') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please select region.', 'कृपया क्षेत्र चुनें।'))),
      );
      return;
    }
    if (_selectedIssue == 'Samasya chune') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please select issue.', 'कृपया समस्या चुनें।'))),
      );
      return;
    }
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please describe the issue.', 'कृपया समस्या का विवरण लिखें।'))),
      );
      return;
    }
    if (!_gpsCaptured || _gpsLatitude == null || _gpsLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Please capture live GPS location first.', 'कृपया पहले लाइव GPS लोकेशन कैप्चर करें।'))),
      );
      return;
    }

    setState(() => _submittingTicket = true);
    try {
      final http.Response response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/v1/rsa/tickets'),
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'phone_number': primaryPhone,
          'alternate_phone_number': alternatePhoneForApi,
          'region': _selectedRegion,
          'issue': _selectedIssue,
          'description': description,
          'gps_latitude': _gpsLatitude,
          'gps_longitude': _gpsLongitude,
          'metadata': <String, dynamic>{
            'source': 'flutter_app',
          },
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Could not submit RSA ticket.';
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            message = '${decoded['detail']}';
          }
        } catch (_) {}
        throw Exception(message);
      }
      final dynamic decoded = jsonDecode(response.body);
      int? ticketId;
      final Map<String, dynamic>? createdTicket = _safeMap(decoded);
      if (createdTicket != null) {
        ticketId = createdTicket['id'] is int
            ? createdTicket['id'] as int
            : int.tryParse(_safeText(createdTicket['id']));
      }
      if (!mounted) return;
      setState(() {
        _submittedTicketId = ticketId;
        _currentStep = 3;
        _selectedTicketTab = 0;
      });
      await _loadRsaTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('RSA ticket submitted successfully.', 'RSA टिकट सफलतापूर्वक सबमिट हो गया।'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingTicket = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pageBg = isDark ? const Color(0xFF050B16) : const Color(0xFFFFF9EA);
    final Color cardBgSoft = isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFBF1);
    final Color border = isDark ? const Color(0x263B82F6) : const Color(0x40F4B400);
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        title: Text(_tr('Raise RSA Ticket', 'RSA टिकट बनाएं')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _RsaTicketHero(isHindi: _isHindi),
          const SizedBox(height: 16),
          _RsaStepProgress(isDark: isDark, currentStep: _currentStep, isHindi: _isHindi),
          const SizedBox(height: 18),
          _GuideCard(
            isDark: isDark,
            isHindi: _isHindi,
            expanded: _showGuide,
            onToggle: () => setState(() => _showGuide = !_showGuide),
          ),
          const SizedBox(height: 14),
          if (_currentStep == 0)
            _RiderVerificationCard(
              isDark: isDark,
              cardBgSoft: cardBgSoft,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              phoneController: _phoneController,
              loadingProfilePhone: _loadingProfilePhone,
              hasPrefilledPhone: _phoneController.text.trim().isNotEmpty,
              isHindi: _isHindi,
              onVerify: _verifyRider,
            )
          else ...[
            _RsaProfileSummaryCard(
              isDark: isDark,
              isHindi: _isHindi,
              phone: _verifiedPhone.isEmpty ? _phoneController.text.trim() : _verifiedPhone,
              name: _profileName,
              riderId: _profileRiderId,
              vehicleCompany: _vehicleCompany,
              vehicleModel: _vehicleModel,
              vehicleNumber: _vehicleNumber,
              totalTickets: _tickets.length,
            ),
            const SizedBox(height: 16),
            _RsaTicketTabs(
              isHindi: _isHindi,
              selectedIndex: _selectedTicketTab,
              onChanged: (int index) {
                setState(() => _selectedTicketTab = index);
                if (index != 1) {
                  _loadRsaTickets();
                }
              },
            ),
            const SizedBox(height: 14),
            if (_currentStep == 3 && _selectedTicketTab == 1)
              _RsaSuccessCard(isDark: isDark, ticketId: _submittedTicketId, isHindi: _isHindi)
            else if (_selectedTicketTab == 0)
              _RsaTicketListPanel(
                isDark: isDark,
                isHindi: _isHindi,
                loading: _loadingTickets,
                error: _ticketsError,
                tickets: _tickets.where((RsaTicketItem item) => item.isActive).toList(),
                emptyMessage: _tr('No active RSA tickets right now.', 'अभी कोई एक्टिव RSA टिकट नहीं है।'),
                onRefresh: _loadRsaTickets,
              )
            else if (_selectedTicketTab == 1)
              _NewTicketCard(
                isDark: isDark,
                isHindi: _isHindi,
                alternatePhoneController: _alternatePhoneController,
                descriptionController: _descriptionController,
                selectedRegion: _selectedRegion,
                selectedIssue: _selectedIssue,
                gpsCaptured: _gpsCaptured,
                detectingGps: _detectingGps,
                gpsLatitude: _gpsLatitude,
                gpsLongitude: _gpsLongitude,
                gpsError: _gpsError,
                submitting: _submittingTicket,
                onRegionChanged: (String value) => setState(() => _selectedRegion = value),
                onIssueChanged: (String value) => setState(() => _selectedIssue = value),
                onCaptureGps: _captureLiveGps,
                onContinue: _submitRsaTicket,
              )
            else
              _RsaTicketListPanel(
                isDark: isDark,
                isHindi: _isHindi,
                loading: _loadingTickets,
                error: _ticketsError,
                tickets: _tickets,
                emptyMessage: _tr('RSA ticket history will appear here.', 'RSA टिकट हिस्ट्री यहां दिखेगी।'),
                onRefresh: _loadRsaTickets,
              ),
          ],
        ],
      ),
    );
  }
}

class _RiderVerificationCard extends StatelessWidget {
  const _RiderVerificationCard({
    required this.isDark,
    required this.isHindi,
    required this.cardBgSoft,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.phoneController,
    required this.loadingProfilePhone,
    required this.hasPrefilledPhone,
    required this.onVerify,
  });

  final bool isDark;
  final bool isHindi;
  final Color cardBgSoft;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final TextEditingController phoneController;
  final bool loadingProfilePhone;
  final bool hasPrefilledPhone;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return _RsaSurface(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            isDark: isDark,
            icon: Icons.badge_rounded,
            title: isHindi ? 'राइडर वेरिफिकेशन' : 'Rider Verification',
            subtitle: isHindi
                ? 'अपना Ride With Garv रजिस्टर्ड मोबाइल नंबर डालें'
                : 'Enter your Ride With Garv registered mobile number',
          ),
          const SizedBox(height: 16),
          Text(
            isHindi ? 'रजिस्टर्ड मोबाइल' : 'Registered mobile',
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: isHindi ? '10 अंकों का मोबाइल नंबर' : '10-digit mobile number',
              helperText: loadingProfilePhone
                  ? (isHindi ? 'आपका प्रोफाइल मोबाइल नंबर लोड हो रहा है...' : 'Fetching your profile mobile number...')
                  : (hasPrefilledPhone
                      ? (isHindi ? 'यह आपके प्रोफाइल से भरा गया है। चाहें तो बदल सकते हैं।' : 'Auto-filled from your profile. You can edit it.')
                      : null),
              helperStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
              filled: true,
              fillColor: cardBgSoft,
              prefixIcon: Icon(
                Icons.phone_iphone_rounded,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0B1F3A),
              ),
              border: _inputBorder(border),
              enabledBorder: _inputBorder(border),
              focusedBorder: _inputBorder(const Color(0xFFF59E0B), width: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onVerify,
              icon: const Icon(Icons.verified_user_rounded),
              label: Text(isHindi ? 'राइडर वेरिफाई करें' : 'Verify Rider'),
              style: _primaryButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaProfileSummaryCard extends StatelessWidget {
  const _RsaProfileSummaryCard({
    required this.isDark,
    required this.isHindi,
    required this.phone,
    required this.name,
    required this.riderId,
    required this.vehicleCompany,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.totalTickets,
  });

  final bool isDark;
  final bool isHindi;
  final String phone;
  final String name;
  final String riderId;
  final String vehicleCompany;
  final String vehicleModel;
  final String vehicleNumber;
  final int totalTickets;

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);
    final String displayName = name.isEmpty ? (isHindi ? 'राइडर' : 'Rider') : name;
    final String initial = displayName.trim().isEmpty ? 'R' : displayName.trim()[0].toUpperCase();
    final String displayPhone = phone.isNotEmpty ? phone : (isHindi ? 'फोन उपलब्ध नहीं' : 'Phone not available');
    final String displayRiderId = riderId.isNotEmpty ? riderId : (isHindi ? 'राइडर आईडी सेट नहीं' : 'Rider ID not set');
    return _RsaSurface(
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFF7A00),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: $displayRiderId - $displayPhone',
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool oneColumn = constraints.maxWidth < 360;
              final List<Widget> tiles = [
                _ProfileInfoTile(
                  label: isHindi ? 'कंपनी' : 'Company',
                  value: vehicleCompany.isEmpty ? (isHindi ? 'जोड़ा नहीं' : 'Not added') : vehicleCompany,
                ),
                _ProfileInfoTile(
                  label: isHindi ? 'वाहन मॉडल' : 'Vehicle model',
                  value: vehicleModel.isEmpty ? (isHindi ? 'जोड़ा नहीं' : 'Not added') : vehicleModel,
                ),
                _ProfileInfoTile(
                  label: isHindi ? 'वाहन नंबर' : 'Vehicle no.',
                  value: vehicleNumber.isEmpty ? (isHindi ? 'जोड़ा नहीं' : 'Not added') : vehicleNumber,
                ),
              ];
              if (oneColumn) {
                return Column(
                  children: [
                    for (final Widget tile in tiles) ...[
                      tile,
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
                children: tiles,
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool oneColumn = constraints.maxWidth < 360;
              final List<Widget> bottomTiles = [
                _ProfileInfoTile(label: isHindi ? 'कुल टिकट' : 'Total tickets', value: '$totalTickets'),
              ];
              if (oneColumn) {
                return Column(
                  children: [
                    bottomTiles[0],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: bottomTiles[0]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x1F64748B) : const Color(0x26F4B400),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFF59E0B)
                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A)),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaTicketTabs extends StatelessWidget {
  const _RsaTicketTabs({
    required this.isHindi,
    required this.selectedIndex,
    required this.onChanged,
  });

  final bool isHindi;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<IconData> icons = [
      Icons.confirmation_number_rounded,
      Icons.add_rounded,
      Icons.history_rounded,
    ];
    final List<String> labels = isHindi
        ? <String>['एक्टिव टिकट', 'नया टिकट', 'हिस्ट्री']
        : <String>['Active Ticket', 'New Ticket', 'History'];

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selectedIndex == i ? const Color(0xFFF59E0B) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 15,
                      color: selectedIndex == i
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewTicketCard extends StatelessWidget {
  const _NewTicketCard({
    required this.isDark,
    required this.isHindi,
    required this.alternatePhoneController,
    required this.descriptionController,
    required this.selectedRegion,
    required this.selectedIssue,
    required this.gpsCaptured,
    required this.detectingGps,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.gpsError,
    required this.submitting,
    required this.onRegionChanged,
    required this.onIssueChanged,
    required this.onCaptureGps,
    required this.onContinue,
  });

  final bool isDark;
  final bool isHindi;
  final TextEditingController alternatePhoneController;
  final TextEditingController descriptionController;
  final String selectedRegion;
  final String selectedIssue;
  final bool gpsCaptured;
  final bool detectingGps;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String? gpsError;
  final bool submitting;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onIssueChanged;
  final VoidCallback onCaptureGps;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final Color fieldBg = isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFBF1);
    final Color border = isDark ? const Color(0x263B82F6) : const Color(0x40F4B400);

    InputDecoration decoration(
      String label,
      String hint,
      IconData icon, {
      bool showIcon = true,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: showIcon
            ? Icon(
                icon,
                color: isDark ? const Color(0xFFFFD166) : const Color(0xFFB45309),
              )
            : null,
        filled: true,
        fillColor: fieldBg,
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(const Color(0xFFF59E0B), width: 1.4),
      );
    }

    return _RsaSurface(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            isDark: isDark,
            icon: Icons.assignment_rounded,
            title: isHindi ? 'नया टिकट' : 'New Ticket',
            subtitle: isHindi ? 'RSA रिक्वेस्ट के लिए जानकारी भरें' : 'Fill details to raise RSA request',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: alternatePhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: decoration(
              isHindi ? 'वैकल्पिक नंबर' : 'Alternative number',
              isHindi ? '10 अंकों का वैकल्पिक नंबर (वैकल्पिक)' : '10-digit alternative number (optional)',
              Icons.phone_in_talk_rounded,
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedRegion,
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'Region chune', child: Text(isHindi ? 'क्षेत्र चुनें' : 'Region chune')),
                    DropdownMenuItem(value: 'Delhi NCR', child: Text('Delhi NCR')),
                    DropdownMenuItem(value: 'Noida', child: Text('Noida')),
                    DropdownMenuItem(value: 'Gurgaon', child: Text('Gurgaon')),
                    DropdownMenuItem(value: 'Ghaziabad', child: Text('Ghaziabad')),
                  ],
                  onChanged: (String? value) {
                    if (value != null) onRegionChanged(value);
                  },
                  decoration: decoration(
                    isHindi ? 'क्षेत्र *' : 'Region *',
                    '',
                    Icons.location_city_rounded,
                    showIcon: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedIssue,
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'Samasya chune', child: Text(isHindi ? 'समस्या चुनें' : 'Samasya chune')),
                    DropdownMenuItem(value: 'Battery issue', child: Text('Battery issue')),
                    DropdownMenuItem(value: 'Puncture', child: Text('Puncture')),
                    DropdownMenuItem(value: 'Towing', child: Text('Towing')),
                    DropdownMenuItem(value: 'Accident help', child: Text('Accident help')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (String? value) {
                    if (value != null) onIssueChanged(value);
                  },
                  decoration: decoration(
                    isHindi ? 'समस्या *' : 'Issue *',
                    '',
                    Icons.report_problem_rounded,
                    showIcon: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: decoration(
              isHindi ? 'विवरण *' : 'Description *',
              isHindi ? 'समस्या का संक्षिप्त विवरण लिखें...' : 'Briefly describe the problem...',
              Icons.notes_rounded,
              showIcon: false,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isHindi ? 'GPS लोकेशन' : 'GPS location',
            style: TextStyle(
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF5B6B84),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: detectingGps || submitting ? null : onCaptureGps,
              icon: detectingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(gpsCaptured ? Icons.check_circle_rounded : Icons.satellite_alt_rounded),
              label: Text(
                detectingGps
                    ? (isHindi ? 'लाइव लोकेशन पता की जा रही है...' : 'Detecting live location...')
                    : (gpsCaptured
                        ? (isHindi ? 'GPS लोकेशन कैप्चर हो गई' : 'GPS Location Captured')
                        : (isHindi ? 'GPS लोकेशन कैप्चर करें' : 'Capture GPS Location')),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor:
                    gpsCaptured ? const Color(0xFF10B981) : const Color(0xFF083C5A),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (gpsCaptured && gpsLatitude != null && gpsLongitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lat: ${gpsLatitude!.toStringAsFixed(5)}, Lng: ${gpsLongitude!.toStringAsFixed(5)}',
              style: TextStyle(
                color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF047857),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          if (gpsError != null && gpsError!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              gpsError!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: gpsCaptured && !submitting ? onContinue : null,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF172033),
                      ),
                    )
                  : const Icon(Icons.location_pin),
              label: Text(
                submitting
                    ? (isHindi ? 'सबमिट हो रहा है...' : 'Submitting...')
                    : (gpsCaptured
                        ? (isHindi ? 'आगे बढ़ें' : 'Continue')
                        : (isHindi ? 'पहले लोकेशन कैप्चर करें' : 'Capture Location First')),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFFF59E0B),
                disabledBackgroundColor: const Color(0xFFB45309),
                foregroundColor: const Color(0xFF172033),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.78),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleTicketPanel extends StatelessWidget {
  const _SimpleTicketPanel({
    required this.isDark,
    required this.message,
    required this.icon,
  });

  final bool isDark;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _RsaSurface(
      isDark: isDark,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaSuccessCard extends StatelessWidget {
  const _RsaSuccessCard({
    required this.isDark,
    required this.isHindi,
    required this.ticketId,
  });

  final bool isDark;
  final bool isHindi;
  final int? ticketId;

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);

    return _RsaSurface(
      isDark: isDark,
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF10B981),
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isHindi ? 'RSA टिकट सबमिट हो गया' : 'RSA Ticket Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ticketId == null
                ? (isHindi
                    ? 'आपकी रिक्वेस्ट दर्ज हो गई है। हमारी सपोर्ट टीम जल्द संपर्क करेगी।'
                    : 'Your request has been captured. Our support team will contact you shortly.')
                : (isHindi
                    ? 'टिकट #$ticketId दर्ज हो गया है। हमारी सपोर्ट टीम जल्द संपर्क करेगी।'
                    : 'Ticket #$ticketId has been captured. Our support team will contact you shortly.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaTicketListPanel extends StatelessWidget {
  const _RsaTicketListPanel({
    required this.isDark,
    required this.isHindi,
    required this.loading,
    required this.error,
    required this.tickets,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final bool isDark;
  final bool isHindi;
  final bool loading;
  final String? error;
  final List<RsaTicketItem> tickets;
  final String emptyMessage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);
    return _RsaSurface(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number_rounded, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHindi ? 'RSA टिकट्स' : 'RSA Tickets',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null && error!.isNotEmpty)
            Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
              ),
            )
          else if (loading && tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tickets.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < tickets.length; i++) ...[
                  _RsaTicketTile(ticket: tickets[i], isDark: isDark, isHindi: isHindi),
                  if (i != tickets.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RsaTicketTile extends StatelessWidget {
  const _RsaTicketTile({
    required this.ticket,
    required this.isDark,
    required this.isHindi,
  });

  final RsaTicketItem ticket;
  final bool isDark;
  final bool isHindi;

  String get _statusLabel {
    switch (ticket.status) {
      case 'assigned':
        return isHindi ? 'असाइन' : 'Assigned';
      case 'in_progress':
        return isHindi ? 'प्रगति में' : 'In progress';
      case 'resolved':
        return isHindi ? 'सुलझा' : 'Resolved';
      case 'cancelled':
        return isHindi ? 'रद्द' : 'Cancelled';
      default:
        return isHindi ? 'नया' : 'New';
    }
  }

  Color get _statusColor {
    switch (ticket.status) {
      case 'resolved':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'assigned':
      case 'in_progress':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String get _dateLabel {
    final DateTime? parsed = DateTime.tryParse(ticket.createdAt);
    if (parsed == null) return ticket.createdAt;
    final DateTime local = parsed.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1F64748B) : const Color(0x26F4B400),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.id} • ${ticket.issue.isEmpty ? (isHindi ? 'RSA समस्या' : 'RSA issue') : ticket.issue}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.28)),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${ticket.region.isEmpty ? (isHindi ? 'क्षेत्र' : 'Region') : ticket.region} • $_dateLabel',
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (ticket.description.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
          if (ticket.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${isHindi ? 'एडमिन नोट्स' : 'Admin notes'}: ${ticket.adminNotes}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.86),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
          if (ticket.assignedToName.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${isHindi ? 'असाइन किया गया' : 'Assigned to'}: ${ticket.assignedToName}',
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          if (ticket.hasLocation) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => openRsaTicketMap(ticket),
                icon: const Icon(Icons.map_rounded, size: 17),
                label: Text(isHindi ? 'मैप्स में लोकेशन खोलें' : 'Open location on Maps'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RsaSurface extends StatelessWidget {
  const _RsaSurface({
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x263B82F6) : const Color(0x40F4B400),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x1AF4B400),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isDark ? const Color(0xFF3B2711) : const Color(0xFFFFE9B5),
          child: Icon(
            icon,
            size: 19,
            color: isDark ? const Color(0xFFFFD166) : const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RsaTicketHero extends StatelessWidget {
  const _RsaTicketHero({required this.isHindi});

  final bool isHindi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071426), Color(0xFF0B1F3A), Color(0xFFB45309)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B1F3A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'राइड विद गर्व RSA' : 'Ride With Garv RSA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isHindi ? 'RSA टिकट\nबनाएं' : 'Raise RSA\nTicket',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isHindi ? 'तेज राइडर मदद - EV सपोर्ट - दिल्ली NCR' : 'Tez rider help - EV support - Delhi NCR',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFFFFD166),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaStepProgress extends StatelessWidget {
  const _RsaStepProgress({
    required this.isDark,
    required this.currentStep,
    required this.isHindi,
  });

  final bool isDark;
  final int currentStep;
  final bool isHindi;

  @override
  Widget build(BuildContext context) {
    final List<String> labels =
        isHindi ? <String>['वेरिफाई', 'प्रोफाइल', 'टिकट', 'पूरा'] : <String>['Verify', 'Profile', 'Ticket', 'Done'];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _StepDot(
            number: i + 1,
            label: labels[i],
            active: i == currentStep,
            completed: i < currentStep,
            isDark: isDark,
          ),
          if (i != labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep
                    ? const Color(0xFF10B981)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFE0A3)),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
    required this.isDark,
  });

  final int number;
  final String label;
  final bool active;
  final bool completed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color bg = completed
        ? const Color(0xFF10B981)
        : active
            ? const Color(0xFFF59E0B)
            : (isDark ? const Color(0xFF15243A) : const Color(0xFFFFE9B5));
    final Color fg = (completed || active) ? const Color(0xFF172033) : const Color(0xFF64748B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bg,
          child: completed
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: completed
                ? const Color(0xFF10B981)
                : active
                    ? (isDark ? const Color(0xFFFFD166) : const Color(0xFF0B1F3A))
                    : const Color(0xFF64748B),
            fontWeight: (active || completed) ? FontWeight.w900 : FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.isDark,
    required this.isHindi,
    required this.expanded,
    required this.onToggle,
  });

  final bool isDark;
  final bool isHindi;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x334B5563) : const Color(0x40F4B400),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: textPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isHindi ? 'RSA टिकट कैसे बनाएं' : 'How to Raise RSA Ticket',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  expanded ? (isHindi ? 'छुपाएं' : 'Hide') : (isHindi ? 'दिखाएं' : 'Show'),
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isHindi
                    ? 'अपना राइडर मोबाइल नंबर वेरिफाई करें, प्रोफाइल जानकारी कन्फर्म करें, टिकट की समस्या और लोकेशन जोड़ें, फिर सबमिट करें। हमारी सपोर्ट टीम रिक्वेस्ट ट्रैक करेगी।'
                    : 'Verify your rider mobile number, confirm profile details, add ticket issue and location, then submit. Our support team will track the request.',
                style: TextStyle(
                  color: textSecondary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    backgroundColor: const Color(0xFFF59E0B),
    foregroundColor: const Color(0xFF172033),
    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

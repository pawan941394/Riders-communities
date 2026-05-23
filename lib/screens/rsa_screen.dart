import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'rsa_ticket_screen.dart';

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

class RsaScreen extends StatefulWidget {
  const RsaScreen({
    super.key,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
    required this.onOpenOnboarding,
    this.initialPhone = '',
  });

  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;
  final VoidCallback onOpenOnboarding;
  final String initialPhone;

  @override
  State<RsaScreen> createState() => _RsaScreenState();
}

class _RsaScreenState extends State<RsaScreen> {
  bool _loadingHistory = false;
  String? _historyError;
  List<RsaTicketItem> _historyTickets = <RsaTicketItem>[];
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  Map<String, String> get _headers {
    return <String, String>{
      'X-API-Key': widget.apiAccessKey,
      'Authorization': 'Bearer ${widget.accessToken.trim()}',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadLandingHistory();
  }

  Future<void> _loadLandingHistory() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final http.Response response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/rsa/tickets?limit=5'),
        headers: _headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Could not load RSA history.';
        try {
          final dynamic decoded = jsonDecode(response.body);
          final Map<String, dynamic>? root = _safeMap(decoded);
          if (root?['detail'] != null) message = _safeText(root?['detail']);
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
          if (item == null) continue;
          final int ticketId =
              item['id'] is int ? item['id'] as int : int.tryParse(_safeText(item['id'])) ?? 0;
          Map<String, dynamic> enriched = item;
          if (ticketId > 0) {
            try {
              final http.Response detailResponse = await http.get(
                Uri.parse('${widget.apiBaseUrl}/api/v1/rsa/tickets/$ticketId'),
                headers: _headers,
              );
              if (detailResponse.statusCode >= 200 && detailResponse.statusCode < 300) {
                final Map<String, dynamic>? detail = _safeMap(jsonDecode(detailResponse.body));
                if (detail != null) enriched = detail;
              }
            } catch (_) {}
          }
          rows.add(RsaTicketItem.fromJson(enriched));
        }
      }
      if (!mounted) return;
      setState(() {
        _historyTickets = rows;
        _historyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<bool> _hasRequiredOnboarding() async {
    final String token = widget.accessToken.trim();
    if (token.isEmpty) return false;

    try {
      String riderId = '';
      final http.Response profileResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/auth/me'),
        headers: _headers,
      );
      if (profileResponse.statusCode >= 200 && profileResponse.statusCode < 300) {
        final dynamic decoded = jsonDecode(profileResponse.body);
        final Map<String, dynamic>? root = _safeMap(decoded);
        final Map<String, dynamic>? profile = _safeMap(root?['profile']);
        if (profile != null) {
          riderId = _safeText(profile['rider_id']);
        }
      }

      final http.Response vehicleResponse = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/v1/vehicle/me'),
        headers: _headers,
      );
      if (vehicleResponse.statusCode < 200 || vehicleResponse.statusCode >= 300) {
        return false;
      }
      final dynamic decoded = jsonDecode(vehicleResponse.body);
      final Map<String, dynamic>? root = _safeMap(decoded);
      final bool hasVehicle = root?['vehicle'] != null;
      return hasVehicle && riderId.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openTicketOrOnboarding(BuildContext context) async {
    final bool ready = await _hasRequiredOnboarding();
    if (!context.mounted) return;
    if (!ready) {
      _showOnboardingRequiredDialog(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RsaTicketScreen(
          apiBaseUrl: widget.apiBaseUrl,
          apiAccessKey: widget.apiAccessKey,
          accessToken: widget.accessToken,
          languageCode: widget.languageCode,
          initialPhone: widget.initialPhone,
        ),
      ),
    ).then((_) => _loadLandingHistory());
  }

  void _showOnboardingRequiredDialog(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFFFFBF1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_tr('Complete onboarding first', 'पहले ऑनबोर्डिंग पूरा करें')),
          content: Text(
            _tr(
              'RSA ticket raise karne se pehle Rider ID aur vehicle details add karni zaroori hain.\n\nBefore raising an RSA ticket, please add your Rider ID and vehicle details.',
              'RSA टिकट बनाने से पहले Rider ID और वाहन की जानकारी जोड़ना जरूरी है।',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr('Later', 'बाद में')),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onOpenOnboarding();
              },
              icon: const Icon(Icons.assignment_ind_rounded),
              label: Text(_tr('Go to onboarding', 'ऑनबोर्डिंग पर जाएं')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pageBg = isDark ? const Color(0xFF0B1220) : const Color(0xFFFFF9EA);
    final Color panelBorder = isDark ? const Color(0x334B5563) : const Color(0x40F4B400);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool compact = screenWidth < 390;
    final double heroHeight = compact ? 740 : 680;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Container(
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: SizedBox(
              height: heroHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/rsa_hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF061325).withValues(alpha: 0.9),
                            const Color(0xFF0B1F3A).withValues(alpha: 0.52),
                            const Color(0xFF061325).withValues(alpha: 0.86),
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            (isDark ? const Color(0xFF08111F) : const Color(0xFF061325))
                                .withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Text(
                        _tr('Ride With Garv Assistance', 'राइड विद गर्व असिस्टेंस'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'RSA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.w900,
                          fontSize: 48,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tr('Rescue Ready', 'रेस्क्यू रेडी'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 32 : 38,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr('Ride rukegi nahi, help turant milegi', 'राइड रुकेगी नहीं, मदद तुरंत मिलेगी'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 19 : 22,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tr(
                          'Breakdown, puncture, towing aur urgent rider support',
                          'ब्रेकडाउन, पंचर, टोइंग और तुरंत राइडर सपोर्ट',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: compact ? 12 : 20,
                        runSpacing: 10,
                        children: [
                          _RsaCircleBadge(label: 'SOS', size: compact ? 82 : 92, fontSize: compact ? 20 : 22),
                          _RsaCircleBadge(label: '24x7', size: compact ? 82 : 92, fontSize: compact ? 20 : 22),
                          _RsaCircleBadge(label: 'NCR', size: compact ? 82 : 92, fontSize: compact ? 20 : 22),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _tr('RIDER SUPPORT SERVICES', 'राइडर सपोर्ट सर्विसेज'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 13 : 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: compact ? 6 : 8,
                        runSpacing: 8,
                        children: [
                          _RsaFeatureChip(
                            icon: Icons.bolt_rounded,
                            label: _tr('Fast Response', 'फास्ट रिस्पॉन्स'),
                            compact: compact,
                          ),
                          _RsaFeatureChip(
                            icon: Icons.build_rounded,
                            label: _tr('Trained Technicians', 'ट्रेन्ड टेक्नीशियन'),
                            compact: compact,
                          ),
                          _RsaFeatureChip(
                            icon: Icons.location_on_rounded,
                            label: _tr('Live Location', 'लाइव लोकेशन'),
                            compact: compact,
                          ),
                          _RsaFeatureChip(
                            icon: Icons.support_agent_rounded,
                            label: _tr('Rider Helpdesk', 'राइडर हेल्पडेस्क'),
                            compact: compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _openTicketOrOnboarding(context),
                        icon: const Icon(Icons.sos_rounded),
                        label: Text(_tr('Raise RSA Ticket Now', 'अभी RSA टिकट बनाएं')),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF1F2937),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tr('Gaadi kharab? Turant ticket darj karein', 'गाड़ी खराब? तुरंत टिकट दर्ज करें'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _RsaLandingHistoryCard(
          isDark: isDark,
          isHindi: _isHindi,
          loading: _loadingHistory,
          error: _historyError,
          tickets: _historyTickets,
          onRefresh: _loadLandingHistory,
        ),
      ],
    );
  }
}

class _RsaCircleBadge extends StatelessWidget {
  const _RsaCircleBadge({
    required this.label,
    this.size = 92,
    this.fontSize = 22,
  });

  final String label;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.95),
        border: Border.all(color: const Color(0xFF111827), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFF0B1220),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
        ),
      ),
    );
  }
}

class _RsaFeatureChip extends StatelessWidget {
  const _RsaFeatureChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 6 : 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFCD34D), size: compact ? 13 : 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsaLandingHistoryCard extends StatelessWidget {
  const _RsaLandingHistoryCard({
    required this.isDark,
    required this.isHindi,
    required this.loading,
    required this.error,
    required this.tickets,
    required this.onRefresh,
  });

  final bool isDark;
  final bool isHindi;
  final bool loading;
  final String? error;
  final List<RsaTicketItem> tickets;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final Color bg = isDark ? const Color(0xFF111827) : const Color(0xFFFFFBF1);
    final Color border = isDark ? const Color(0x334B5563) : const Color(0x40F4B400);
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHindi ? 'आपकी RSA हिस्ट्री' : 'Your RSA History',
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
              isHindi ? 'अभी कोई RSA टिकट हिस्ट्री नहीं है।' : 'Abhi koi RSA ticket history nahi hai.',
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < tickets.length; i++) ...[
                  _RsaLandingHistoryTile(ticket: tickets[i], isDark: isDark),
                  if (i != tickets.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RsaLandingHistoryTile extends StatelessWidget {
  const _RsaLandingHistoryTile({
    required this.ticket,
    required this.isDark,
  });

  final RsaTicketItem ticket;
  final bool isDark;

  String get _statusLabel {
    switch (ticket.status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'New';
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
    final Color tileBg = isDark ? const Color(0xFF0B1220) : Colors.white;
    final Color border = isDark ? const Color(0x1F64748B) : const Color(0x26F4B400);
    final Color textPrimary = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF5B6B84);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.id} • ${ticket.issue.isEmpty ? 'RSA issue' : ticket.issue}',
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
            '${ticket.region.isEmpty ? 'Region' : ticket.region} • $_dateLabel',
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
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          if (ticket.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Admin notes: ${ticket.adminNotes}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.86),
                fontWeight: FontWeight.w800,
                height: 1.3,
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
                label: const Text('Open location on Maps'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

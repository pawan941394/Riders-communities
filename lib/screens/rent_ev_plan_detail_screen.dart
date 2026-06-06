import 'package:flutter/material.dart';

import '../models/rent_ev_plan.dart';
import '../services/ev_interest_api.dart';
import '../widgets/rent_ev_partner_image.dart';

/// Full-screen detail for one rental partner.
class RentEvPlanDetailScreen extends StatefulWidget {
  const RentEvPlanDetailScreen({
    super.key,
    required this.plan,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
  });

  final RentEvPlan plan;
  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;

  static String rupee(num amount) {
    final double v = amount.toDouble();
    if (v == v.roundToDouble()) {
      return '₹${v.toInt()}';
    }
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  State<RentEvPlanDetailScreen> createState() => _RentEvPlanDetailScreenState();
}

class _RentEvPlanDetailScreenState extends State<RentEvPlanDetailScreen> {
  bool _interestSubmitted = false;
  bool _submitting = false;

  RentEvPlan get plan => widget.plan;

  Future<void> _onInterested() async {
    if (_interestSubmitted || _submitting) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (widget.accessToken.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Log in to save your interest — we need your account to follow up.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await submitEvPlanInterest(
        apiBaseUrl: widget.apiBaseUrl,
        apiAccessKey: widget.apiAccessKey,
        accessToken: widget.accessToken,
        channel: 'rent',
        planSlug: plan.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _interestSubmitted = true;
        _submitting = false;
      });
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${plan.companyName} — interest saved. The team can see this in admin.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } on EvInterestException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.message, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Could not reach the server. Try again.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final Color border = isDark ? const Color(0x335B6B88) : const Color(0x1F000000);
    final Color themeAccent = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(plan.companyName),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: (_interestSubmitted || _submitting) ? null : _onInterested,
                icon: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Icon(_interestSubmitted ? Icons.check_circle_rounded : Icons.favorite_rounded),
                label: Text(
                  _submitting
                      ? 'Saving…'
                      : (_interestSubmitted ? 'Interest shared' : "I'm interested"),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _interestSubmitted ? const Color(0xFF059669) : const Color(0xFF0B1F3A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF059669),
                  disabledForegroundColor: Colors.white,
                ),
              ),
              if (!_interestSubmitted && !_submitting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap to show interest — booking flow will connect later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (plan.hasPartnerImage) ...[
            RentEvPartnerHeroImage(plan: plan),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    icon: Icons.payments_outlined,
                    label: '${RentEvPlanDetailScreen.rupee(plan.dailyRent)}/day',
                    accent: themeAccent,
                    isDark: isDark,
                  ),
                  _SummaryChip(
                    icon: Icons.calendar_view_week_rounded,
                    label: '${RentEvPlanDetailScreen.rupee(plan.weeklyRent)}/wk',
                    accent: themeAccent,
                    isDark: isDark,
                  ),
                  _SummaryChip(
                    icon: Icons.shield_outlined,
                    label: '${RentEvPlanDetailScreen.rupee(plan.securityDeposit)} deposit',
                    accent: themeAccent,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF1F2937), Color(0xFF0F172A)]
                        : const [Color(0xFF0B1F3A), Color(0xFF111827)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x33000000) : const Color(0x1A000000),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RentEvPartnerAvatar(plan: plan, size: 52, borderRadius: 16),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              plan.tagline,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroChip(
                        icon: Icons.payments_outlined,
                        label: '${RentEvPlanDetailScreen.rupee(plan.dailyRent)}/day',
                      ),
                      _HeroChip(
                        icon: Icons.calendar_view_week_rounded,
                        label: '${RentEvPlanDetailScreen.rupee(plan.weeklyRent)}/wk',
                      ),
                      _HeroChip(
                        icon: Icons.shield_outlined,
                        label: '${RentEvPlanDetailScreen.rupee(plan.securityDeposit)} deposit',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pricing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 14),
                _RentRow(
                  Icons.shield_outlined,
                  'Security deposit',
                  '${RentEvPlanDetailScreen.rupee(plan.securityDeposit)}/-',
                  isDark: isDark,
                  accent: themeAccent,
                ),
                const SizedBox(height: 12),
                _RentRow(
                  Icons.calendar_view_week_rounded,
                  'Weekly rent',
                  '${RentEvPlanDetailScreen.rupee(plan.weeklyRent)}/-',
                  isDark: isDark,
                  accent: themeAccent,
                  subtitle: '(${RentEvPlanDetailScreen.rupee(plan.dailyRent)}/- per day)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Documents required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF374151) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${plan.documentCount} items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: themeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...plan.documentsRequired.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            doc,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334E68),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Partner terms may change. Confirm on call or official app before paying deposit.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF4B5563) : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RentRow extends StatelessWidget {
  const _RentRow(
    this.icon,
    this.label,
    this.value, {
    required this.isDark,
    required this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF374151) : accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF102A56),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

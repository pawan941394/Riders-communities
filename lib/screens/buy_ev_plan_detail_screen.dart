import 'package:flutter/material.dart';

import '../models/buy_ev_plan.dart';
import '../services/ev_interest_api.dart';
import '../widgets/buy_ev_partner_image.dart';

/// Purchase / finance detail — **not** rental; uses [BuyEvPlan] only.
class BuyEvPlanDetailScreen extends StatefulWidget {
  const BuyEvPlanDetailScreen({
    super.key,
    required this.plan,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
  });

  final BuyEvPlan plan;
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
  State<BuyEvPlanDetailScreen> createState() => _BuyEvPlanDetailScreenState();
}

class _BuyEvPlanDetailScreenState extends State<BuyEvPlanDetailScreen> {
  bool _interestSubmitted = false;
  bool _submitting = false;

  BuyEvPlan get plan => widget.plan;

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
        channel: 'buy',
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
    final Color cardBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
    final Color border = isDark ? const Color(0x335B6B88) : const Color(0x33F4B400);
    const Color lightPageBg = Color(0xFFFFFFFF);
    const Color navy = Color(0xFF0B1F3A);
    const Color amber = Color(0xFFF4B400);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : lightPageBg,
      appBar: AppBar(
        title: Text(plan.companyName),
        backgroundColor: isDark ? const Color(0xFF0B1220) : lightPageBg,
        surfaceTintColor: Colors.transparent,
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
                    : Icon(_interestSubmitted ? Icons.check_circle_rounded : Icons.shopping_bag_rounded),
                label: Text(
                  _submitting
                      ? 'Saving…'
                      : (_interestSubmitted ? 'Interest shared' : "I'm interested to buy"),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _interestSubmitted ? const Color(0xFF059669) : navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF059669),
                  disabledForegroundColor: Colors.white,
                ),
              ),
              if (!_interestSubmitted && !_submitting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Shows intent for purchase / finance — not rent. Final quote from dealer.',
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
            BuyEvPartnerHeroImage(plan: plan),
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
                  _BuySummaryChip(
                    icon: Icons.storefront_outlined,
                    label: 'From ${BuyEvPlanDetailScreen.rupee(plan.exShowroomFrom)}',
                    accent: plan.accentA,
                    isDark: isDark,
                  ),
                  if (plan.emiAvailable)
                    _BuySummaryChip(
                      icon: Icons.payments_outlined,
                      label: 'EMI available',
                      accent: plan.accentA,
                      isDark: isDark,
                    ),
                  if (plan.downPaymentOptionsAvailable)
                    _BuySummaryChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Down payment options',
                      accent: plan.accentA,
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
                  colors: [plan.accentA, plan.accentB],
                ),
                boxShadow: [
                  BoxShadow(
                    color: plan.accentA.withValues(alpha: 0.35),
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
                      BuyEvPartnerAvatar(plan: plan, size: 52, borderRadius: 16),
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
                      _BuyHeroChip(
                        icon: Icons.storefront_outlined,
                        label: 'From ${BuyEvPlanDetailScreen.rupee(plan.exShowroomFrom)}',
                      ),
                      if (plan.emiAvailable)
                        const _BuyHeroChip(
                          icon: Icons.payments_outlined,
                          label: 'EMI available',
                        ),
                      if (plan.downPaymentOptionsAvailable)
                        const _BuyHeroChip(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Down payment options',
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
                  'Buy & finance (indicative)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'EMI & down payment ₹ amounts are not shown here — bank rates change and our platform commission is reflected in the final partner quote.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                _BuyPricingRow(
                  Icons.storefront_outlined,
                  'Starting (ex-showroom)',
                  '${BuyEvPlanDetailScreen.rupee(plan.exShowroomFrom)}/-',
                  isDark: isDark,
                  accent: plan.accentA,
                  subtitle: 'On-road, insurance & reg. extra',
                ),
                if (plan.emiAvailable) ...[
                  const SizedBox(height: 12),
                  _BuyPricingRow(
                    Icons.payments_outlined,
                    'EMI',
                    'Available — exact EMI on enquiry',
                    isDark: isDark,
                    accent: plan.accentA,
                    subtitle: 'Depends on bank, tenure & live rates; approval required.',
                  ),
                ],
                if (plan.downPaymentOptionsAvailable) ...[
                  const SizedBox(height: 12),
                  _BuyPricingRow(
                    Icons.account_balance_wallet_outlined,
                    'Down payment',
                    'Options available — discuss with advisor',
                    isDark: isDark,
                    accent: plan.accentA,
                    subtitle: 'Structure varies by partner; final numbers on call.',
                  ),
                ],
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
                      'Documents (finance / booking)',
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
                        color: (isDark ? const Color(0xFF374151) : const Color(0xFFFFF2CC)),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isDark ? Colors.transparent : const Color(0x66F4B400),
                        ),
                      ),
                      child: Text(
                        '${plan.documentCount} items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF93C5FD) : navy,
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
                          color: isDark ? const Color(0xFF34D399) : amber,
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
            'Ex-showroom is indicative. EMI/down payment figures are shared by the partner when you enquire — not rental. Platform commission may be included in partner pricing.',
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

class _BuySummaryChip extends StatelessWidget {
  const _BuySummaryChip({
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
        color: isDark ? const Color(0xFF374151) : const Color(0xFFFFF2CC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF4B5563) : const Color(0x66F4B400),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? accent : const Color(0xFF0B1F3A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyHeroChip extends StatelessWidget {
  const _BuyHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
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

class _BuyPricingRow extends StatelessWidget {
  const _BuyPricingRow(
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
            color: isDark ? const Color(0xFF374151) : const Color(0xFFFFF2CC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.transparent : const Color(0x66F4B400),
            ),
          ),
          child: Icon(icon, size: 22, color: isDark ? accent : const Color(0xFF0B1F3A)),
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

import 'package:flutter/material.dart';

import '../models/rent_ev_plan.dart';
import '../services/rent_ev_api.dart';
import '../widgets/rent_ev_partner_image.dart';
import 'rent_ev_plan_detail_screen.dart';

/// Browse rental partners — data from `/api/v1/ev/rent-plans`.
class RentEvScreen extends StatefulWidget {
  const RentEvScreen({
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
  State<RentEvScreen> createState() => _RentEvScreenState();
}

class _RentEvScreenState extends State<RentEvScreen> {
  final TextEditingController _search = TextEditingController();

  List<RentEvPlan> _plans = <RentEvPlan>[];
  bool _loading = true;
  String? _error;
  bool get _isHindi => widget.languageCode.toLowerCase().startsWith('hi');
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<RentEvPlan> list = await fetchRentEvPlans(
        apiBaseUrl: widget.apiBaseUrl,
        apiAccessKey: widget.apiAccessKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = list;
        _loading = false;
        _error = null;
      });
    } on RentEvApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _tr(
          'Could not reach the server. Check your connection and try again.',
          'सर्वर से कनेक्ट नहीं हो पाया। अपना कनेक्शन चेक करें और फिर कोशिश करें।',
        );
      });
    }
  }

  List<RentEvPlan> _filtered(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _plans;
    }
    return _plans.where((RentEvPlan p) {
      return p.companyName.toLowerCase().contains(q) || p.tagline.toLowerCase().contains(q);
    }).toList();
  }

  void _openDetail(RentEvPlan plan) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RentEvPlanDetailScreen(
          plan: plan,
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
    final String q = _search.text;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
      body: RefreshIndicator(
        onRefresh: _loadPlans,
        color: const Color(0xFF0B1F3A),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
              surfaceTintColor: Colors.transparent,
              title: const SizedBox.shrink(),
            ),
            if (_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 52,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loadPlans,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_tr('Retry', 'फिर कोशिश करें')),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B1F3A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_plans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 52,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _tr('No Rent EV partners yet.', 'अभी कोई Rent EV पार्टनर नहीं है।'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(
                          'Pull down to refresh once partners are added in admin.',
                          'एडमिन में पार्टनर जुड़ने के बाद रिफ्रेश करने के लिए नीचे खींचें।',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [Color(0xFF1F2937), Color(0xFF0F172A), Color(0xFF111827)]
                                : const [Color(0xFF0B1F3A), Color(0xFF1E3A5F), Color(0xFF111827)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? const Color(0x33000000) : const Color(0x1A000000),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr('Rent EV', 'ईवी किराए पर लें'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _tr(
                                'Compare deposits, weekly rent and documents across companies — live list from our backend.',
                                'कंपनियों के डिपॉजिट, साप्ताहिक किराया और डॉक्यूमेंट्स की तुलना करें — लाइव लिस्ट हमारे बैकएंड से।',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: _tr('Search company or tagline...', 'कंपनी या टैगलाइन खोजें...'),
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          suffixIcon: q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: _tr('Clear', 'साफ करें'),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0x335B6B88) : const Color(0x1F000000),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0x335B6B88) : const Color(0x1F000000),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF0B1F3A), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        q.trim().isEmpty
                            ? _tr('All partners', 'सभी पार्टनर्स')
                            : _tr('Results', 'रिजल्ट्स'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_filtered(q).length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_filtered(q).isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.electric_scooter_rounded,
                            size: 56,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _tr('No partner matches "$q"', '"$q" से कोई पार्टनर नहीं मिला'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            child: Text(_tr('Clear search', 'सर्च साफ करें')),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: _filtered(q).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (BuildContext context, int index) {
                      final RentEvPlan p = _filtered(q)[index];
                      return _PartnerCard(
                        plan: p,
                        languageCode: widget.languageCode,
                        onTap: () => _openDetail(p),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.plan,
    required this.onTap,
    this.languageCode = 'en',
  });

  final RentEvPlan plan;
  final VoidCallback onTap;
  final String languageCode;
  bool get _isHindi => languageCode.toLowerCase().startsWith('hi');
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final Color border = isDark ? const Color(0x335B6B88) : const Color(0x1F000000);
    final Color textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF102A56);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _PartnerCardMedia(plan: plan),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            plan.companyName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              letterSpacing: -0.3,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        if (plan.featured)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [plan.accentA, plan.accentB],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _tr('Featured', 'फीचर्ड'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 28,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.tagline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.calendar_today_outlined,
                          label: '${RentEvPlanDetailScreen.rupee(plan.dailyRent)}/${_tr('day', 'दिन')}',
                          isDark: isDark,
                          highlight: true,
                        ),
                        _InfoPill(
                          icon: Icons.date_range_outlined,
                          label: '${RentEvPlanDetailScreen.rupee(plan.weeklyRent)}/${_tr('week', 'हफ्ता')}',
                          isDark: isDark,
                        ),
                        if (plan.securityDeposit > 0)
                          _InfoPill(
                            icon: Icons.account_balance_wallet_outlined,
                            label: '${RentEvPlanDetailScreen.rupee(plan.securityDeposit)} ${_tr('deposit', 'डिपॉजिट')}',
                            isDark: isDark,
                          ),
                        _InfoPill(
                          icon: Icons.description_outlined,
                          label: _isHindi
                              ? '${plan.documentCount} ${plan.documentCount == 1 ? 'डॉक्यूमेंट' : 'डॉक्यूमेंट्स'}'
                              : '${plan.documentCount} document${plan.documentCount == 1 ? '' : 's'}',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _tr('Tap for full plan', 'पूरा प्लान देखने के लिए टैप करें'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: plan.accentB.withValues(alpha: isDark ? 0.95 : 1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: plan.accentA,
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
}

/// Large hero area — partner photo edge-to-edge or branded gradient + initial.
class _PartnerCardMedia extends StatelessWidget {
  const _PartnerCardMedia({required this.plan});

  final RentEvPlan plan;

  @override
  Widget build(BuildContext context) {
    final String raw = (plan.imageUrl ?? '').trim();
    if (raw.isNotEmpty) {
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final int decodeWidth =
          (MediaQuery.sizeOf(context).width * dpr).round().clamp(400, 1600);
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            raw,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            cacheWidth: decodeWidth,
            errorBuilder: (_, _, _) => _gradientFallback(context),
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
              if (progress == null) {
                return child;
              }
              return ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                child: Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: plan.accentA,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _gradientFallback(context);
  }

  Widget _gradientFallback(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            plan.accentA,
            plan.accentB,
          ],
        ),
      ),
      child: Text(
        RentEvPartnerAvatar.letter(plan.companyName),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 72,
          height: 1,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.isDark,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlight
            ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFF8FAFC))
            : (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? (isDark ? const Color(0xFF3B82F6) : const Color(0x1F000000))
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0B1F3A),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

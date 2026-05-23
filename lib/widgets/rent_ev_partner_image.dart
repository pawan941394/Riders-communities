import 'package:flutter/material.dart';

import '../models/rent_ev_plan.dart';

/// Company avatar for list rows: network image when [RentEvPlan.imageUrl] is set, else gradient + initial.
class RentEvPartnerAvatar extends StatelessWidget {
  const RentEvPartnerAvatar({
    super.key,
    required this.plan,
    required this.size,
    this.borderRadius = 14,
  });

  final RentEvPlan plan;
  final double size;
  final double borderRadius;

  static String letter(String name) {
    for (final int c in name.runes) {
      final String ch = String.fromCharCode(c);
      if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) {
        return ch.toUpperCase();
      }
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final String raw = (plan.imageUrl ?? '').trim();
    if (raw.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          raw,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(context),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              child: SizedBox(
                width: size * 0.38,
                height: size * 0.38,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: plan.accentA,
                ),
              ),
            );
          },
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            plan.accentA.withValues(alpha: 0.88),
            plan.accentB.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: plan.accentA.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        letter(plan.companyName),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// Detail hero: **16:9** frame (same aspect as YouTube thumbnails) so the full EV /
/// bike reads clearly edge-to-edge; title sits on a bottom scrim only.
class RentEvPartnerHeroImage extends StatelessWidget {
  const RentEvPartnerHeroImage({
    super.key,
    required this.plan,

    /// YouTube-style thumbnail = **16:9**. Change only if you need another ratio.
    this.aspectRatio = 16 / 9,
  });

  final RentEvPlan plan;

  /// Width ÷ height (16÷9 ≈ 1.78).
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final String raw = (plan.imageUrl ?? '').trim();
    if (raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int decodeWidth = (MediaQuery.sizeOf(context).width * dpr).round().clamp(400, 2048);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                raw,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                cacheWidth: decodeWidth,
                errorBuilder: (_, _, _) => _errorFallback(context),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE2E8F0),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(color: plan.accentA),
                  );
                },
              ),
              // Keep upper ~55% of the frame clear so riders see the bike / EV clearly.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.42, 0.65, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: [
                          Shadow(offset: Offset(0, 1), blurRadius: 10, color: Color(0xAA000000)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(offset: Offset(0, 1), blurRadius: 8, color: Color(0x99000000)),
                        ],
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

  Widget _errorFallback(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: plan.accentA.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

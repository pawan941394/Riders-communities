import 'package:flutter/material.dart';

/// Purchase listing for **buy** flow. EMI / downpayment amounts are **not** stored —
/// partners change rates; platform commission is folded into final quotes separately.
///
/// Loaded from backend `/api/v1/ev/buy-plans` (see [BuyEvPlan.fromJson]).
class BuyEvPlan {
  const BuyEvPlan({
    required this.id,
    required this.companyName,
    required this.tagline,
    required this.exShowroomFrom,
    required this.documentsRequired,
    required this.accentA,
    required this.accentB,
    this.imageUrl,
    this.emiAvailable = true,
    this.downPaymentOptionsAvailable = true,
  });

  final String id;
  final String companyName;
  final String tagline;

  /// Indicative starting ex-showroom — finer quote from dealer.
  final double exShowroomFrom;

  final List<String> documentsRequired;
  final Color accentA;
  final Color accentB;
  final String? imageUrl;

  /// Partner offers EMI (exact figure shared separately — rates change).
  final bool emiAvailable;

  /// Partner offers down-payment / finance structuring (no fixed ₹ here).
  final bool downPaymentOptionsAvailable;

  int get documentCount => documentsRequired.length;

  bool get hasPartnerImage => (imageUrl ?? '').trim().isNotEmpty;

  factory BuyEvPlan.fromJson(Map<String, dynamic> json) {
    final List<String> docs = <String>[];
    final Object? dr = json['documentsRequired'];
    if (dr is List<dynamic>) {
      for (final Object? x in dr) {
        if (x != null) {
          docs.add(x.toString());
        }
      }
    }
    return BuyEvPlan(
      id: json['id'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      exShowroomFrom: _asDouble(json['exShowroomFrom']),
      documentsRequired: docs,
      accentA: Color(_asInt(json['accentA']) ?? 0xFF000000),
      accentB: Color(_asInt(json['accentB']) ?? 0xFF000000),
      imageUrl: _optionalImageUrl(json['imageUrl']),
      emiAvailable: json['emiAvailable'] as bool? ?? true,
      downPaymentOptionsAvailable: json['downPaymentOptionsAvailable'] as bool? ?? true,
    );
  }

  static double _asDouble(Object? v) {
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v) ?? 0;
    }
    return 0;
  }

  static int? _asInt(Object? v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return null;
  }

  static String? _optionalImageUrl(Object? v) {
    if (v == null) {
      return null;
    }
    final String s = v is String ? v : v.toString();
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }
}

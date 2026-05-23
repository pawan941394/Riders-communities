import 'package:flutter/material.dart';

/// Rental partner row — loaded from `/api/v1/ev/rent-plans`.
class RentEvPlan {
  const RentEvPlan({
    required this.id,
    required this.companyName,
    required this.tagline,
    required this.securityDeposit,
    required this.weeklyRent,
    required this.dailyRent,
    required this.documentsRequired,
    required this.accentA,
    required this.accentB,
    this.featured = false,
    this.imageUrl,
  });

  final String id;
  final String companyName;
  final String tagline;
  final double securityDeposit;
  final double weeklyRent;
  final double dailyRent;
  final List<String> documentsRequired;
  final Color accentA;
  final Color accentB;
  final bool featured;

  /// Partner hero / list thumbnail (HTTPS).
  final String? imageUrl;

  int get documentCount => documentsRequired.length;

  bool get hasPartnerImage => (imageUrl ?? '').trim().isNotEmpty;

  factory RentEvPlan.fromJson(Map<String, dynamic> json) {
    final List<String> docs = <String>[];
    final Object? dr = json['documentsRequired'];
    if (dr is List<dynamic>) {
      for (final Object? x in dr) {
        if (x != null) {
          docs.add(x.toString());
        }
      }
    }
    return RentEvPlan(
      id: json['id'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      securityDeposit: _asDouble(json['securityDeposit']),
      weeklyRent: _asDouble(json['weeklyRent']),
      dailyRent: _asDouble(json['dailyRent']),
      documentsRequired: docs,
      accentA: Color(_asInt(json['accentA']) ?? 0xFF000000),
      accentB: Color(_asInt(json['accentB']) ?? 0xFF000000),
      featured: json['featured'] as bool? ?? false,
      imageUrl: _optionalImageUrl(json['imageUrl']),
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

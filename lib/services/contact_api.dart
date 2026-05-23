import 'dart:convert';

import 'package:http/http.dart' as http;

/// Inquiry dropdown row from `GET /api/v1/contact/meta`.
class InquiryKindOption {
  const InquiryKindOption({required this.value, required this.label});

  final String value;
  final String label;

  factory InquiryKindOption.fromJson(Map<String, dynamic> json) {
    return InquiryKindOption(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

/// Tile from admin [InquiryIssue] — Help or EV hub.
class InquiryIssueTile {
  const InquiryIssueTile({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.detailDescription,
    required this.iconKey,
  });

  final String slug;
  final String title;
  final String subtitle;
  final String detailDescription;
  final String iconKey;

  factory InquiryIssueTile.fromJson(Map<String, dynamic> json) {
    return InquiryIssueTile(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      detailDescription: json['detailDescription'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
    );
  }
}

/// Full payload from `GET /api/v1/contact/meta` (kinds + optional tile lists).
class ContactLayoutMeta {
  const ContactLayoutMeta({
    required this.inquiryKinds,
    required this.helpTiles,
    required this.evHubTiles,
  });

  final List<InquiryKindOption> inquiryKinds;
  final List<InquiryIssueTile> helpTiles;
  final List<InquiryIssueTile> evHubTiles;
}

Future<ContactLayoutMeta> fetchContactLayoutMeta({
  required String apiBaseUrl,
  required String apiAccessKey,
}) async {
  final Uri uri = Uri.parse('$apiBaseUrl/api/v1/contact/meta');
  final http.Response res = await http.get(
    uri,
    headers: <String, String>{'X-API-Key': apiAccessKey},
  );
  if (res.statusCode != 200) {
    throw ContactApiException('Could not load contact options (${res.statusCode}).');
  }
  final Object? decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw const ContactApiException('Invalid contact meta response.');
  }
  final List<dynamic>? rawKinds = decoded['inquiryKinds'] as List<dynamic>?;
  if (rawKinds == null) {
    throw const ContactApiException('Invalid contact meta: missing inquiryKinds.');
  }
  final List<InquiryKindOption> kinds = rawKinds
      .whereType<Map<String, dynamic>>()
      .map(InquiryKindOption.fromJson)
      .toList();

  final List<dynamic>? rawHelp = decoded['helpTiles'] as List<dynamic>?;
  final List<InquiryIssueTile> helpTiles = rawHelp == null
      ? <InquiryIssueTile>[]
      : rawHelp
          .whereType<Map<String, dynamic>>()
          .map(InquiryIssueTile.fromJson)
          .toList();

  final List<dynamic>? rawEv = decoded['evHubTiles'] as List<dynamic>?;
  final List<InquiryIssueTile> evHubTiles = rawEv == null
      ? <InquiryIssueTile>[]
      : rawEv
          .whereType<Map<String, dynamic>>()
          .map(InquiryIssueTile.fromJson)
          .toList();

  return ContactLayoutMeta(
    inquiryKinds: kinds,
    helpTiles: helpTiles,
    evHubTiles: evHubTiles,
  );
}

/// Backwards-compatible: only inquiry kinds (same endpoint).
Future<List<InquiryKindOption>> fetchContactMeta({
  required String apiBaseUrl,
  required String apiAccessKey,
}) async {
  final ContactLayoutMeta m = await fetchContactLayoutMeta(
    apiBaseUrl: apiBaseUrl,
    apiAccessKey: apiAccessKey,
  );
  return m.inquiryKinds;
}

/// `POST /api/v1/contact/submissions` — requires logged-in user; server fills name/email/phone from profile.
Future<int> submitContact({
  required String apiBaseUrl,
  required String apiAccessKey,
  required String accessToken,
  required String inquiryKind,
  required String message,
}) async {
  final String t = accessToken.trim();
  if (t.isEmpty) {
    throw const ContactApiException('You must be logged in to send a message.');
  }
  final Uri uri = Uri.parse('$apiBaseUrl/api/v1/contact/submissions');
  final http.Response res = await http.post(
    uri,
    headers: <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': apiAccessKey,
      'Authorization': 'Bearer $t',
    },
    body: jsonEncode(<String, dynamic>{
      'inquiry_kind': inquiryKind,
      'message': message.trim(),
    }),
  );
  if (res.statusCode == 201) {
    final Object? decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic> && decoded['id'] is int) {
      return decoded['id'] as int;
    }
    if (decoded is Map<String, dynamic> && decoded['id'] is num) {
      return (decoded['id'] as num).toInt();
    }
    return 0;
  }
  String msg = 'Could not send message (${res.statusCode}).';
  try {
    final Object? d = jsonDecode(res.body);
    if (d is Map && d['detail'] != null) {
      msg = d['detail'].toString();
    }
  } catch (_) {}
  throw ContactApiException(msg, statusCode: res.statusCode);
}

class ContactApiException implements Exception {
  const ContactApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

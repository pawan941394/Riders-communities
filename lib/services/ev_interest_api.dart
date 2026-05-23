import 'dart:convert';

import 'package:http/http.dart' as http;

/// POST `/api/v1/ev/interests` — requires `X-API-Key` + `Authorization: Bearer`.
Future<void> submitEvPlanInterest({
  required String apiBaseUrl,
  required String apiAccessKey,
  required String accessToken,
  required String channel,
  required String planSlug,
  String? partnerLabel,
}) async {
  final Uri uri = Uri.parse('$apiBaseUrl/api/v1/ev/interests');
  final Map<String, dynamic> body = <String, dynamic>{
    'channel': channel,
    'plan_slug': planSlug,
  };
  final String? pl = partnerLabel?.trim();
  if (pl != null && pl.isNotEmpty) {
    body['partner_label'] = pl;
  }
  final http.Response res = await http.post(
    uri,
    headers: <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': apiAccessKey,
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode(body),
  );
  if (res.statusCode == 200) {
    return;
  }
  throw EvInterestException(
    _messageFromBody(res.body) ?? 'Could not save interest (${res.statusCode}).',
    statusCode: res.statusCode,
  );
}

String? _messageFromBody(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final Object? detail = decoded['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List<dynamic> && detail.isNotEmpty) {
        final Object? first = detail.first;
        if (first is Map<String, dynamic>) {
          final Object? msg = first['msg'];
          if (msg != null) {
            return msg.toString();
          }
        }
      }
    }
  } catch (_) {}
  return null;
}

class EvInterestException implements Exception {
  const EvInterestException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

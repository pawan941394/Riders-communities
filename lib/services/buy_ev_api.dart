import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/buy_ev_plan.dart';

/// Loads Buy EV partner rows from FastAPI `/api/v1/ev/buy-plans`.
Future<List<BuyEvPlan>> fetchBuyEvPlans({
  required String apiBaseUrl,
  required String apiAccessKey,
}) async {
  final Uri uri = Uri.parse('$apiBaseUrl/api/v1/ev/buy-plans');
  final http.Response res = await http.get(
    uri,
    headers: <String, String>{'X-API-Key': apiAccessKey},
  );
  if (res.statusCode != 200) {
    throw BuyEvApiException(
      'Could not load Buy EV plans (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final Object? decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw const BuyEvApiException('Invalid Buy EV response shape.');
  }
  final List<dynamic>? rawItems = decoded['items'] as List<dynamic>?;
  if (rawItems == null) {
    throw const BuyEvApiException('Invalid Buy EV response: missing items.');
  }
  final List<BuyEvPlan> out = [];
  for (final Object? el in rawItems) {
    if (el is Map<String, dynamic>) {
      out.add(BuyEvPlan.fromJson(el));
    }
  }
  return out;
}

class BuyEvApiException implements Exception {
  const BuyEvApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

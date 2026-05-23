import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/rent_ev_plan.dart';

/// Loads Rent EV partner rows from FastAPI `/api/v1/ev/rent-plans`.
Future<List<RentEvPlan>> fetchRentEvPlans({
  required String apiBaseUrl,
  required String apiAccessKey,
}) async {
  final Uri uri = Uri.parse('$apiBaseUrl/api/v1/ev/rent-plans');
  final http.Response res = await http.get(
    uri,
    headers: <String, String>{'X-API-Key': apiAccessKey},
  );
  if (res.statusCode != 200) {
    throw RentEvApiException(
      'Could not load Rent EV plans (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final Object? decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw const RentEvApiException('Invalid Rent EV response shape.');
  }
  final List<dynamic>? rawItems = decoded['items'] as List<dynamic>?;
  if (rawItems == null) {
    throw const RentEvApiException('Invalid Rent EV response: missing items.');
  }
  final List<RentEvPlan> out = <RentEvPlan>[];
  for (final Object? el in rawItems) {
    if (el is Map<String, dynamic>) {
      out.add(RentEvPlan.fromJson(el));
    }
  }
  return out;
}

class RentEvApiException implements Exception {
  const RentEvApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

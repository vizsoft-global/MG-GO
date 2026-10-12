import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'rider_backend.dart';

/// Isolate-safe callable invoke (no FlutterFire plugins).
///
/// Body is the gen2 callable envelope `{ data }`. Error `message` stays the
/// old RPC string so [decodeRpcError] / [dutyRejectionFrom] keep working.
Future<Map<String, dynamic>> callRiderFunctionHttp({
  required String name,
  required String idToken,
  Map<String, dynamic>? data,
}) async {
  final projectId = Env.firebaseProjectId;
  final uri = Uri.https(
    '$riderFunctionsRegion-$projectId.cloudfunctions.net',
    '/$name',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'data': data ?? <String, dynamic>{}}),
  );

  final decoded = _decodeJsonMap(response.body);
  if (response.statusCode >= 200 && response.statusCode < 300) {
    final result = decoded['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return decoded;
  }

  final error = decoded['error'];
  if (error is Map) {
    final message = (error['message'] as String?)?.trim();
    final details = error['details'];
    if (details is Map && details['error'] is String) {
      throw RiderCallableHttpException(
        details['error'] as String,
        statusCode: response.statusCode,
        details: Map<String, dynamic>.from(details),
      );
    }
    if (message != null && message.isNotEmpty) {
      throw RiderCallableHttpException(
        message,
        statusCode: response.statusCode,
        details: details is Map ? Map<String, dynamic>.from(details) : null,
      );
    }
  }

  throw RiderCallableHttpException(
    'server_error',
    statusCode: response.statusCode,
  );
}

Map<String, dynamic> _decodeJsonMap(String body) {
  if (body.isEmpty) return <String, dynamic>{};
  final parsed = jsonDecode(body);
  if (parsed is Map) return Map<String, dynamic>.from(parsed);
  return <String, dynamic>{};
}

class RiderCallableHttpException implements Exception {
  RiderCallableHttpException(
    this.code, {
    this.statusCode,
    this.details,
  });

  final String code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() => code;
}

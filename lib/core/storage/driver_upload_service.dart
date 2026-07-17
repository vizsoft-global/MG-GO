import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class DriverUploadException implements Exception {
  DriverUploadException({this.message = '', this.code});

  final String message;
  final String? code;

  @override
  String toString() => message.isNotEmpty ? message : (code ?? 'upload_failed');
}

class DriverUploadResult {
  const DriverUploadResult({required this.objectKey, required this.sizeBytes});

  final String objectKey;
  final int sizeBytes;
}

class OrderProofReadUrl {
  const OrderProofReadUrl({required this.readUrl, this.contentType});

  final String readUrl;
  final String? contentType;
}

/// Presign → PUT → confirm (proxy fallback). No R2 credentials in the app.
class DriverUploadService {
  DriverUploadService(this._client);

  final SupabaseClient _client;

  static const _orderProofMaxBytes = 10 * 1024 * 1024;
  static const _driverAvatarMaxBytes = 2 * 1024 * 1024;

  Future<DriverUploadResult> uploadOrderProof({
    required List<int> bytes,
    required String contentType,
    required String filename,
    String? entityId,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw DriverUploadException(code: 'file_empty');
    }
    if (bytes.length > _orderProofMaxBytes) {
      throw DriverUploadException(code: 'file_too_large_order');
    }
    if (!_isAllowedContentType(contentType)) {
      throw DriverUploadException(code: 'invalid_content_type');
    }

    final token = _accessToken();
    final authHeaders = {'Authorization': 'Bearer $token'};

    return _uploadViaPresign(
      bytes: bytes,
      contentType: contentType,
      filename: filename,
      entityType: 'order_proof',
      entityId: entityId,
      authHeaders: authHeaders,
      onProgress: onProgress,
    );
  }

  Future<DriverUploadResult> uploadDriverAvatar({
    required List<int> bytes,
    required String contentType,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw DriverUploadException(code: 'file_empty');
    }
    if (bytes.length > _driverAvatarMaxBytes) {
      throw DriverUploadException(code: 'file_too_large_avatar');
    }
    if (!_isAllowedContentType(contentType)) {
      throw DriverUploadException(code: 'invalid_content_type');
    }

    final token = _accessToken();
    final authHeaders = {'Authorization': 'Bearer $token'};
    return _uploadViaPresign(
      bytes: bytes,
      contentType: contentType,
      filename: filename,
      entityType: 'driver_avatar',
      authHeaders: authHeaders,
      onProgress: onProgress,
    );
  }

  Future<DriverUploadResult> _uploadViaPresign({
    required List<int> bytes,
    required String contentType,
    required String filename,
    required String entityType,
    required Map<String, String> authHeaders,
    String? entityId,
    void Function(double progress)? onProgress,
  }) async {
    final presignRes = await http.post(
      Uri.parse('${Env.adminApiBaseUrl}/api/driver-uploads/presign'),
      headers: {...authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'entityType': entityType,
        'entityId': entityId,
        'contentType': contentType,
        'filename': filename,
        'sizeBytes': bytes.length,
      }),
    );

    if (presignRes.statusCode != 200) {
      throw DriverUploadException(
        message: _errorMessage(presignRes, ''),
        code: 'presign_failed',
      );
    }

    final presign = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final uploadUrl = presign['uploadUrl'] as String;
    final uploadId = presign['uploadId'] as String;
    final objectKey = presign['objectKey'] as String;

    onProgress?.call(0.1);

    http.Response? putRes;
    try {
      putRes = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
    } catch (_) {
      // Browser CORS or network failure — fall through to proxy.
    }

    onProgress?.call(0.85);

    final putOk =
        putRes != null && putRes.statusCode >= 200 && putRes.statusCode < 300;

    if (!putOk) {
      return _uploadViaProxy(
        bytes: bytes,
        contentType: contentType,
        filename: filename,
        entityType: entityType,
        entityId: entityId,
        authHeaders: authHeaders,
        onProgress: onProgress,
      );
    }

    final confirmRes = await http.post(
      Uri.parse('${Env.adminApiBaseUrl}/api/driver-uploads/confirm'),
      headers: {...authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'uploadId': uploadId}),
    );

    if (confirmRes.statusCode != 200) {
      throw DriverUploadException(
        message: _errorMessage(confirmRes, ''),
        code: 'confirm_failed',
      );
    }

    onProgress?.call(1.0);
    final confirm = jsonDecode(confirmRes.body) as Map<String, dynamic>;
    return DriverUploadResult(
      objectKey: confirm['objectKey'] as String? ?? objectKey,
      sizeBytes: (confirm['sizeBytes'] as num?)?.toInt() ?? bytes.length,
    );
  }

  Future<DriverUploadResult> _uploadViaProxy({
    required List<int> bytes,
    required String contentType,
    required String filename,
    required String entityType,
    required Map<String, String> authHeaders,
    String? entityId,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${Env.adminApiBaseUrl}/api/driver-uploads/proxy'),
    );
    request.headers.addAll(authHeaders);
    request.fields['entityType'] = entityType;
    if (entityId != null) {
      request.fields['entityId'] = entityId;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (e) {
      throw DriverUploadException(code: 'proxy_network');
    }
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw DriverUploadException(
        message: _parseErrorBody(body) ?? '',
        code: 'proxy_failed',
      );
    }

    onProgress?.call(1.0);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return DriverUploadResult(
      objectKey: json['objectKey'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
    );
  }

  String _accessToken() {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw DriverUploadException(code: 'not_authenticated');
    }
    return session.accessToken;
  }

  bool _isAllowedContentType(String contentType) {
    const allowed = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    };
    return allowed.contains(contentType.toLowerCase());
  }

  Future<OrderProofReadUrl> resolveOrderProofReadUrl(String objectKey) async {
    final resolved = await resolveReadUrl(objectKey);
    return OrderProofReadUrl(
      readUrl: resolved.readUrl,
      contentType: resolved.contentType,
    );
  }

  Future<OrderProofReadUrl> resolveReadUrl(String objectKey) async {
    final trimmed = objectKey.trim();
    if (trimmed.isEmpty) {
      throw DriverUploadException(code: 'proof_missing');
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return OrderProofReadUrl(readUrl: trimmed);
    }

    final token = _accessToken();
    final uri = Uri.parse(
      '${Env.adminApiBaseUrl}/api/driver-uploads/read',
    ).replace(queryParameters: {'objectKey': trimmed});

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 404) {
      throw DriverUploadException(code: 'proof_not_found');
    }
    if (response.statusCode == 403) {
      throw DriverUploadException(code: 'proof_forbidden');
    }
    if (response.statusCode != 200) {
      throw DriverUploadException(
        message: _errorMessage(response, ''),
        code: 'read_failed',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final readUrl = json['readUrl'] as String?;
    if (readUrl == null || readUrl.isEmpty) {
      throw DriverUploadException(code: 'read_failed');
    }

    return OrderProofReadUrl(
      readUrl: readUrl,
      contentType: json['contentType'] as String?,
    );
  }

  String _errorMessage(http.Response res, String fallback) {
    return _parseErrorBody(res.body) ?? fallback;
  }

  String? _parseErrorBody(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      if (err is String) return err.replaceAll('_', ' ');
      if (json['message'] is String) return json['message'] as String;
    } catch (_) {}
    return null;
  }
}

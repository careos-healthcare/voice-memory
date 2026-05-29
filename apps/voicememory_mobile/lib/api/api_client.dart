import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../models/session.dart';
import 'api_errors.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  static const captureTokenHeader = 'x-vm-capture-token';

  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<UserSession?> getSession() async {
    final response = await _http.get(_uri('/api/auth/session'), headers: _jsonHeaders);
    if (response.statusCode >= 500) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = body['session'];
    if (session == null) return null;
    return UserSession.fromJson(session as Map<String, dynamic>);
  }

  Future<AttestResult> postCaptureAttest(String deviceId) async {
    final response = await _http.post(
      _uri('/api/capture/attest'),
      headers: _jsonHeaders,
      body: jsonEncode({'deviceId': deviceId}),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['via'] == 'session') {
      return AttestResult.session(userId: body['userId'] as String? ?? '');
    }
    final token = body['token'] as String?;
    if (token == null || body['ok'] != true) {
      throw ApiException('Attest failed.', statusCode: response.statusCode);
    }
    return AttestResult.capture(
      token: token,
      expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 3600,
    );
  }

  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/transcribe'));
    request.headers[captureTokenHeader] = captureToken;
    request.fields['durationSeconds'] = durationSeconds.toString();
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        filename: _audioFilename(audioFile.path),
      ),
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final transcript = body['transcript'] as String?;
    if (transcript == null || transcript.trim().isEmpty) {
      throw ApiException(
        body['error'] as String? ?? 'No transcript returned',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    return transcript.trim();
  }

  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorContext = const [],
  }) async {
    final response = await _http.post(
      _uri('/api/analyze'),
      headers: {
        ..._jsonHeaders,
        captureTokenHeader: captureToken,
      },
      body: jsonEncode({
        'transcript': transcript,
        'priorContext': priorContext,
      }),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final reflection = body['reflection'] as Map<String, dynamic>?;
    if (reflection == null) {
      throw ApiException('No reflection in response', statusCode: response.statusCode);
    }
    return Reflection.fromJson(reflection);
  }

  Future<List<JournalEntry>> listJournal() async {
    final response = await _http.get(_uri('/api/journal'), headers: _jsonHeaders);
    if (response.statusCode == 401) {
      throw AuthRequiredException();
    }
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = body['entries'] as List<dynamic>? ?? [];
    return entries
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PremiumEntitlements> getEntitlements() async {
    final response =
        await _http.get(_uri('/api/billing/entitlements'), headers: _jsonHeaders);
    if (response.statusCode == 401) {
      throw AuthRequiredException();
    }
    if (!response.statusCode.toString().startsWith('2')) {
      return PremiumEntitlements.free();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PremiumEntitlements.fromJson(body);
  }

  Future<Map<String, dynamic>> health() async {
    final response = await _http.get(_uri('/api/health'), headers: _jsonHeaders);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String _audioFilename(String path) {
    final parts = path.split('.');
    final ext = parts.length > 1 ? parts.last : 'm4a';
    return 'recording.$ext';
  }

  void dispose() => _http.close();
}

class AttestResult {
  const AttestResult._({this.token, this.expiresInSeconds, this.sessionUserId});

  factory AttestResult.capture({
    required String token,
    required int expiresInSeconds,
  }) =>
      AttestResult._(token: token, expiresInSeconds: expiresInSeconds);

  factory AttestResult.session({required String userId}) =>
      AttestResult._(sessionUserId: userId);

  final String? token;
  final int? expiresInSeconds;
  final String? sessionUserId;

  bool get isSession => sessionUserId != null;
}

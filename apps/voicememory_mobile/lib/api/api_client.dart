import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../models/session.dart';
import '../features/archive_synthesis/archive_synthesis_models.dart';
import 'api_errors.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    String? sessionCookie,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _sessionCookie = sessionCookie;

  final http.Client _http;
  final String _baseUrl;
  String? _sessionCookie;

  static const captureTokenHeader = 'x-vm-capture-token';
  static const sessionCookieName = 'vm_session';

  void setSessionCookie(String? cookie) => _sessionCookie = cookie;

  String? get sessionCookie => _sessionCookie;

  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_sessionCookie != null && _sessionCookie!.isNotEmpty)
          'Cookie': _sessionCookie!,
      };

  Uri? _tryUri(String path) {
    if (!AppConfig.isBackendConfigured || _baseUrl.isEmpty) {
      debugPrint('ApiClient: backend not configured — skipping $path');
      return null;
    }
    return Uri.parse('$_baseUrl$path');
  }

  Uri _uri(String path) {
    final uri = _tryUri(path);
    if (uri == null) throw BackendNotConfiguredException();
    return uri;
  }

  // ——— Auth ———

  Future<void> sendAuthCode(String email) async {
    final response = await _http.post(
      _uri('/api/auth/send-code'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email.trim()}),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
  }

  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final response = await _http.post(
      _uri('/api/auth/verify'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final cookie = _extractSessionCookie(response);
    if (cookie != null) _sessionCookie = cookie;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = body['session'] as Map<String, dynamic>?;
    if (session == null) {
      throw ApiException('No session in response', statusCode: response.statusCode);
    }
    return UserSession.fromJson(session);
  }

  Future<UserSession?> getSession() async {
    final uri = _tryUri('/api/auth/session');
    if (uri == null) return null;
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode == 401) return null;
    if (response.statusCode >= 500) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = body['session'];
    if (session == null) return null;
    return UserSession.fromJson(session as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    await _http.post(_uri('/api/auth/signout'), headers: _jsonHeaders);
    _sessionCookie = null;
  }

  // ——— Capture ———

  Future<AttestResult> captureAttest(String deviceId) async =>
      postCaptureAttest(deviceId);

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

  Future<String> transcribeAudio({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
  }) async =>
      postTranscribe(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
      );

  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/transcribe'));
    request.headers[captureTokenHeader] = captureToken;
    if (_sessionCookie != null) request.headers['Cookie'] = _sessionCookie!;
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

  Future<Reflection> analyzeTranscript({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorContext = const [],
  }) async =>
      postAnalyze(
        transcript: transcript,
        captureToken: captureToken,
        priorContext: priorContext,
      );

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

  // ——— Journal ———

  Future<List<JournalEntry>> getJournal() async => listJournal();

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

  Future<void> createJournalEntry(List<JournalEntry> entries) async {
    final response = await _http.post(
      _uri('/api/journal'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
  }

  Future<void> deleteJournalEntry(String id) async {
    final response = await _http.delete(
      _uri('/api/journal/$id'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (response.statusCode == 404) return;
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
  }

  Future<Map<String, dynamic>> exportJournal() async {
    final response = await _http.get(_uri('/api/journal/export'), headers: _jsonHeaders);
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ——— Billing ———

  Future<PremiumEntitlements> getEntitlements() async {
    final uri = _tryUri('/api/billing/entitlements');
    if (uri == null) return PremiumEntitlements.free();
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode == 401) {
      throw AuthRequiredException();
    }
    if (response.statusCode == 503) {
      return PremiumEntitlements.free();
    }
    if (!response.statusCode.toString().startsWith('2')) {
      return PremiumEntitlements.free();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PremiumEntitlements.fromJson(body);
  }

  Future<CheckoutSession> createCheckoutSession() async {
    final response = await _http.post(
      _uri('/api/billing/checkout'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (response.statusCode == 503) {
      throw BillingUnavailableException();
    }
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException('Checkout URL missing', statusCode: response.statusCode);
    }
    return CheckoutSession(
      url: url,
      sessionId: body['sessionId'] as String?,
    );
  }

  // ——— Sync ———

  Future<Map<String, dynamic>> syncManifest() async {
    final response = await _http.get(_uri('/api/sync/manifest'), headers: _jsonHeaders);
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncPull() async {
    final response = await _http.get(_uri('/api/sync/pull'), headers: _jsonHeaders);
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    final response = await _http.post(
      _uri('/api/sync/push'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHealth() async => health();

  Future<Map<String, dynamic>> health() async {
    final response = await _http.get(_uri('/api/health'), headers: _jsonHeaders);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    final response = await _http.post(
      _uri('/api/account/delete'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    _sessionCookie = null;
  }

  static String? _extractSessionCookie(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return null;
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$sessionCookieName=')) {
        final semi = trimmed.indexOf(';');
        return semi > 0 ? trimmed.substring(0, semi) : trimmed;
      }
    }
    return null;
  }

  static String _audioFilename(String path) {
    final parts = path.split('.');
    final ext = parts.length > 1 ? parts.last : 'm4a';
    return 'recording.$ext';
  }

  Future<void> registerPushDevice({
    required String deviceId,
    required String platform,
    required String fcmToken,
  }) async {
    final response = await _http.post(
      _uri('/api/push/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'deviceId': deviceId,
        'platform': platform,
        'fcmToken': fcmToken,
      }),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
  }

  Future<Map<String, dynamic>> sendInternalTestPush({
    required String deviceId,
    required String targetRoute,
    String? debugToken,
  }) async {
    final headers = Map<String, String>.from(_jsonHeaders);
    if (debugToken != null && debugToken.isNotEmpty) {
      headers['x-vm-debug-token'] = debugToken;
    }
    final response = await _http.post(
      _uri('/api/internal/send-test-push'),
      headers: headers,
      body: jsonEncode({
        'deviceId': deviceId,
        'targetRoute': targetRoute,
      }),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// GPT-5 archive synthesis V2 — requires server flag + session/capture auth.
  Future<ArchiveSynthesisApiResponse?> postArchiveSynthesis({
    required ArchiveSynthesisType synthesisType,
    required String monthKey,
    required String userId,
    required Map<String, dynamic> pack,
    int? milestoneThreshold,
  }) async {
    final uri = _tryUri('/api/archive-synthesis');
    if (uri == null) return null;

    final response = await _http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        'synthesisType': synthesisType.apiValue,
        'monthKey': monthKey,
        'userId': userId,
        'pack': pack,
        if (milestoneThreshold != null)
          'milestoneThreshold': milestoneThreshold,
      }),
    );

    if (response.statusCode == 403) return null;
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final type = body['synthesisType']?.toString() ?? synthesisType.apiValue;
    final reviewJson = body['review'];
    if (reviewJson is! Map) return null;
    final map = Map<String, dynamic>.from(reviewJson);

    return ArchiveSynthesisApiResponse(
      synthesisType: type,
      cached: body['cached'] == true,
      monthlyReview: type == 'monthly'
          ? ArchiveMonthlyReview.fromJson(map)
          : null,
      milestoneReview: type == 'milestone'
          ? ArchiveMilestoneReview.fromJson(map)
          : null,
      deepDiveNarrative: type == 'deep_dive'
          ? ArchiveDeepDiveNarrative.fromJson(map)
          : null,
      historianReport: type == 'historian'
          ? ArchiveHistorianReport.fromJson(map)
          : null,
    );
  }

  void dispose() => _http.close();
}

class ArchiveSynthesisApiResponse {
  const ArchiveSynthesisApiResponse({
    required this.synthesisType,
    required this.cached,
    this.monthlyReview,
    this.milestoneReview,
    this.deepDiveNarrative,
    this.historianReport,
  });

  final String synthesisType;
  final bool cached;
  final ArchiveMonthlyReview? monthlyReview;
  final ArchiveMilestoneReview? milestoneReview;
  final ArchiveDeepDiveNarrative? deepDiveNarrative;
  final ArchiveHistorianReport? historianReport;
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

class CheckoutSession {
  const CheckoutSession({required this.url, this.sessionId});

  final String url;
  final String? sessionId;
}

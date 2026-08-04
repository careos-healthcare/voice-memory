import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../features/voice_capture/audio/audio_capture_diagnostics.dart';
import '../features/voice_capture/audio/audio_diag_log.dart';
import '../features/voice_capture/analysis/analysis_log.dart';
import '../features/voice_capture/transcription/transcription_log.dart';
import '../models/entitlement.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../features/proof_admission/proof_admission_models.dart';
import '../models/session.dart';
import '../features/archive_synthesis/archive_synthesis_models.dart';
import '../features/live_audio/domain/models/live_audio_session_config.dart';
import '../features/live_audio/domain/models/offline_vault_manifest.dart';
import '../security/ai_prompt_boundary.dart';
import '../security/api_response_safety.dart';
import '../security/private_log.dart';
import '../security/user_content_safety.dart';
import 'api_errors.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl, String? sessionCookie})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _sessionCookie = sessionCookie;

  final http.Client _http;
  final String _baseUrl;
  String? _sessionCookie;

  static const captureTokenHeader = 'x-vm-capture-token';
  static const sessionCookieName = 'vm_session';
  static const idempotencyHeader = 'x-vm-idempotency-key';

  void setSessionCookie(String? cookie) => _sessionCookie = cookie;

  String? get sessionCookie => _sessionCookie;

  Map<String, String> _headersWithIdempotency({
    required Map<String, String> base,
    String? idempotencyKey,
  }) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return base;
    return {...base, idempotencyHeader: idempotencyKey};
  }

  Map<String, dynamic> _decodeJson(http.Response response) =>
      ApiResponseSafety.decodeJsonObject(response);

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
    if (!ApiResponseSafety.isBaseUrlAllowed(_baseUrl)) {
      debugPrint(
        'ApiClient: rejected API base URL for this build — skipping $path',
      );
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
    final body = _decodeJson(response);
    final session = body['session'] as Map<String, dynamic>?;
    if (session == null) {
      throw ApiException(
        'No session in response',
        statusCode: response.statusCode,
      );
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
    final body = _decodeJson(response);
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
    final body = _decodeJson(response);
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

  /// Mint a short-lived backend live-audio proxy session (never returns Gemini keys).
  Future<LiveAudioSessionConfig> postLiveAudioSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    final response = await _http.post(
      _uri('/api/live-audio/session'),
      headers: _headersWithIdempotency(
        base: {..._jsonHeaders, captureTokenHeader: captureToken},
        idempotencyKey: idempotencyKey,
      ),
      body: jsonEncode({}),
    );
    ApiResponseSafety.ensureJsonResponse(response);
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = _decodeJson(response);
    if (body['ok'] != true) {
      throw ApiException(
        body['error'] as String? ?? 'Live audio session mint failed',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    return LiveAudioSessionConfig.fromJson(body);
  }

  /// Uploads an encrypted offline live-audio vault for server-side recovery.
  Future<VaultRecoveryServerResult> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
  }) async {
    final uri = _uri('/api/live-audio/recover');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $captureToken';
    request.headers[captureTokenHeader] = captureToken;
    request.headers[idempotencyHeader] = idempotencyKey;
    if (_sessionCookie != null) request.headers['Cookie'] = _sessionCookie!;
    request.fields['session_id'] = sessionId;
    if (recoverySecretKeyBytes != null && recoverySecretKeyBytes.length == 32) {
      request.fields['recovery_secret'] = base64Url.encode(
        recoverySecretKeyBytes,
      );
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'vault',
        vaultFile.path,
        filename: vaultFile.uri.pathSegments.last,
        contentType: MediaType('application', 'octet-stream'),
      ),
    );

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    ApiResponseSafety.ensureJsonResponse(response);
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = _decodeJson(response);
    if (body['ok'] != true) {
      throw ApiException(
        body['error'] as String? ?? 'Vault recovery upload failed',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    return VaultRecoveryServerResult.fromJson(body);
  }

  /// Uploads an encrypted vault blob; returns true only on affirmative server ACK.
  Future<bool> uploadEncryptedVault({
    required String sessionId,
    required File file,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
  }) async {
    try {
      final result = await postVaultRecovery(
        vaultFile: file,
        sessionId: sessionId,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        recoverySecretKeyBytes: recoverySecretKeyBytes,
      );
      return result.recoveryAckId.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> transcribeAudio({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
  }) async => postTranscribe(
    audioFile: audioFile,
    durationSeconds: durationSeconds,
    captureToken: captureToken,
  );

  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    final uri = _uri('/api/transcribe');
    TranscriptionLog.request(url: uri.toString());
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers[captureTokenHeader] = captureToken;
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      request.headers[idempotencyHeader] = idempotencyKey;
    }
    if (_sessionCookie != null) request.headers['Cookie'] = _sessionCookie!;
    request.fields['durationSeconds'] = durationSeconds.toString();
    final fileName = _audioFilename(audioFile.path);
    final uploadBytes = audioFile.existsSync() ? audioFile.lengthSync() : 0;
    final contentTypeString = AudioCaptureDiagnostics.uploadContentTypeForPath(
      audioFile.path,
    );
    final contentType = MediaType.parse(contentTypeString);
    AudioDiagLog.upload(
      fileName: fileName,
      contentType: contentTypeString,
      bytes: uploadBytes,
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        filename: fileName,
        contentType: contentType,
      ),
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    TranscriptionLog.response(
      status: response.statusCode,
      contentType: response.headers['content-type'] ?? 'unknown',
    );
    ApiResponseSafety.ensureJsonResponse(response);
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = _decodeJson(response);
    final transcript = body['transcript'] as String?;
    if (transcript == null || transcript.trim().isEmpty) {
      throw ApiException(
        body['error'] as String? ?? 'No transcript returned',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    final sanitized = UserContentSafety.sanitizePlainText(transcript.trim());
    PrivateLog.userTextField(
      tag: 'ApiClient:',
      field: 'transcribe',
      text: sanitized,
    );
    return sanitized;
  }

  /// Raw provider boundary. Only the canonical proof-admission service may
  /// turn this DTO into customer-facing or persistable model output.
  Future<RawModelResponse> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
  }) async {
    final prepared = AiPromptBoundary.prepareUserReflectionForApi(transcript);
    PrivateLog.apiPayload(
      tag: 'ApiClient:',
      operation: 'analyze',
      preparedText: prepared,
    );

    final uri = _uri('/api/analyze');
    AnalysisLog.request(url: uri.toString());
    final response = await _http.post(
      uri,
      headers: _headersWithIdempotency(
        base: {..._jsonHeaders, captureTokenHeader: captureToken},
        idempotencyKey: idempotencyKey,
      ),
      body: jsonEncode({
        'transcript': prepared,
        'priorEvidence': priorEvidence,
      }),
    );
    AnalysisLog.response(
      status: response.statusCode,
      contentType: response.headers['content-type'] ?? 'unknown',
    );
    if (!response.statusCode.toString().startsWith('2')) {
      String? code;
      String reason = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        reason = body['error'] as String? ?? reason;
        code = body['code'] as String?;
      } catch (_) {}
      AnalysisLog.failed(
        status: response.statusCode,
        code: code,
        reason: reason,
      );
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = _decodeJson(response);
    final reflection = body['reflection'] as Map<String, dynamic>?;
    if (reflection == null) {
      AnalysisLog.failed(
        status: response.statusCode,
        reason: 'No reflection in response',
      );
      throw ApiException(
        'No reflection in response',
        statusCode: response.statusCode,
      );
    }
    final parsed = Reflection.fromJson(reflection);
    AnalysisLog.success(
      observationLength: parsed.concreteObservation.trim().length,
    );
    return RawModelResponse(
      payload: body,
      receivedAt: DateTime.now().toUtc(),
      providerResponseId:
          response.headers['x-request-id'] ?? response.headers['request-id'],
    );
  }

  // ——— Journal ———

  Future<List<JournalEntry>> getJournal() async => listJournal();

  Future<List<JournalEntry>> listJournal() async {
    final response = await _http.get(
      _uri('/api/journal'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) {
      throw AuthRequiredException();
    }
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    final body = _decodeJson(response);
    final entries = body['entries'] as List<dynamic>? ?? [];
    return entries
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createJournalEntry(List<JournalEntry> entries) async {
    final response = await _http.post(
      _uri('/api/journal'),
      headers: _jsonHeaders,
      body: jsonEncode({'entries': entries.map((e) => e.toJson()).toList()}),
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
    final response = await _http.get(
      _uri('/api/journal/export'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return _decodeJson(response);
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
    final body = _decodeJson(response);
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
    final body = _decodeJson(response);
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException(
        'Checkout URL missing',
        statusCode: response.statusCode,
      );
    }
    return CheckoutSession(url: url, sessionId: body['sessionId'] as String?);
  }

  // ——— Sync ———

  Future<Map<String, dynamic>> syncManifest() async {
    final response = await _http.get(
      _uri('/api/sync/manifest'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> syncPull() async {
    final response = await _http.get(
      _uri('/api/sync/pull'),
      headers: _jsonHeaders,
    );
    if (response.statusCode == 401) throw AuthRequiredException();
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return _decodeJson(response);
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
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> getHealth() async => health();

  Future<Map<String, dynamic>> health() async {
    final response = await _http.get(
      _uri('/api/health'),
      headers: _jsonHeaders,
    );
    return _decodeJson(response);
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
      body: jsonEncode({'deviceId': deviceId, 'targetRoute': targetRoute}),
    );
    if (!response.statusCode.toString().startsWith('2')) {
      throw ApiErrorMapper.fromResponse(response);
    }
    return _decodeJson(response);
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

    final body = _decodeJson(response);
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
  }) => AttestResult._(token: token, expiresInSeconds: expiresInSeconds);

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

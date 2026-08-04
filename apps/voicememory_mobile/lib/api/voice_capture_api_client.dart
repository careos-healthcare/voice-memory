import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../features/remote_transcription/remote_transcription_disclosure.dart';
import '../features/voice_capture/analysis/analysis_log.dart';
import '../features/voice_capture/audio/audio_capture_diagnostics.dart';
import '../features/voice_capture/audio/audio_diag_log.dart';
import '../features/voice_capture/transcription/transcription_log.dart';
import '../models/reflection.dart';
import '../security/ai_prompt_boundary.dart';
import '../security/api_response_safety.dart';
import '../security/private_log.dart';
import '../security/user_content_safety.dart';
import 'api_exceptions.dart';
import 'api_models.dart';
import 'api_transport.dart';

class VoiceCaptureApiClient {
  VoiceCaptureApiClient(
    this.transport, {
    RemoteTranscriptionDisclosureGate? remoteTranscriptionDisclosure,
  }) : _remoteTranscriptionDisclosure =
           remoteTranscriptionDisclosure ??
           const DeniedRemoteTranscriptionDisclosureGate();

  final ApiTransport transport;
  final RemoteTranscriptionDisclosureGate _remoteTranscriptionDisclosure;

  Future<AttestResult> captureAttest(String deviceId) =>
      postCaptureAttest(deviceId);

  Future<AttestResult> postCaptureAttest(String deviceId) async {
    final response = await transport.postJson(
      '/api/capture/attest',
      body: {'deviceId': deviceId},
    );
    final body = transport.decodeJson(response);
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
  }) => postTranscribe(
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
    final disclosureVersion = await _requireRemoteTranscriptionDisclosure();
    final uri = transport.uri('/api/transcribe');
    TranscriptionLog.request(url: uri.toString());
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers[ApiTransport.captureTokenHeader] = captureToken;
    request.headers[remoteTranscriptionDisclosureHeader] = disclosureVersion;
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      request.headers[ApiTransport.idempotencyHeader] = idempotencyKey;
    }
    final cookie = transport.sessionCookie;
    if (cookie != null) request.headers['Cookie'] = cookie;
    request.fields['durationSeconds'] = durationSeconds.toString();
    final fileName = _audioFilename(audioFile.path);
    final uploadBytes = audioFile.existsSync() ? audioFile.lengthSync() : 0;
    final contentTypeString = AudioCaptureDiagnostics.uploadContentTypeForPath(
      audioFile.path,
    );
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
        contentType: MediaType.parse(contentTypeString),
      ),
    );
    final response = await transport.send(request);
    TranscriptionLog.response(
      status: response.statusCode,
      contentType: response.headers['content-type'] ?? 'unknown',
    );
    ApiResponseSafety.ensureJsonResponse(response);
    final body = transport.decodeJson(response);
    final transcript = body['transcript'] as String?;
    if (transcript == null || transcript.trim().isEmpty) {
      throw ApiException(
        body['error'] as String? ?? 'No transcript returned',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    final sanitized = UserContentSafety.sanitizePlainText(transcript.trim());
    return sanitized;
  }

  Future<Reflection> analyzeTranscript({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? entryId,
  }) => postAnalyze(
    transcript: transcript,
    captureToken: captureToken,
    priorEvidence: priorEvidence,
    entryId: entryId,
  );

  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    final prepared = AiPromptBoundary.prepareUserReflectionForApi(transcript);
    PrivateLog.apiPayload(
      tag: 'VoiceCaptureApiClient:',
      operation: 'analyze',
      preparedText: prepared,
    );

    final uri = transport.uri('/api/analyze');
    AnalysisLog.request(url: uri.toString());
    late final http.Response response;
    try {
      response = await transport.postJson(
        '/api/analyze',
        headers: transport.headersWithIdempotency(
          base: {
            ...transport.jsonHeaders,
            ApiTransport.captureTokenHeader: captureToken,
          },
          idempotencyKey: idempotencyKey,
        ),
        body: {
          // The route applies its own untrusted-content prompt boundary. Send
          // the canonical text here so returned UTF-16 citations address the
          // exact transcript that the journal will persist.
          'transcript': transcript,
          'priorEvidence': priorEvidence,
          if (entryId != null && entryId.trim().isNotEmpty)
            'entryId': entryId.trim(),
        },
      );
    } on ApiException catch (error) {
      AnalysisLog.failed(
        status: error.statusCode ?? 0,
        code: error.code,
        reason: error.message,
      );
      rethrow;
    }
    AnalysisLog.response(
      status: response.statusCode,
      contentType: response.headers['content-type'] ?? 'unknown',
    );
    final body = transport.decodeJson(response);
    final reflection = body['reflection'] as Map<String, dynamic>?;
    if (reflection == null) {
      AnalysisLog.failed(
        status: response.statusCode,
        reason: 'No analysis in response',
      );
      throw ApiException(
        'No analysis in response',
        statusCode: response.statusCode,
      );
    }
    final parsed = Reflection.fromJson(reflection);
    AnalysisLog.success(
      observationLength: parsed.concreteObservation.trim().length,
    );
    return parsed;
  }

  static String _audioFilename(String path) {
    final parts = path.split('.');
    final ext = parts.length > 1 ? parts.last : 'm4a';
    return 'recording.$ext';
  }

  Future<String> _requireRemoteTranscriptionDisclosure() async {
    final result = await _remoteTranscriptionDisclosure.check();
    final version = result.version;
    if (!result.isAccepted || version != remoteTranscriptionDisclosureVersion) {
      throw RemoteDisclosureRequiredException();
    }
    return version!;
  }
}

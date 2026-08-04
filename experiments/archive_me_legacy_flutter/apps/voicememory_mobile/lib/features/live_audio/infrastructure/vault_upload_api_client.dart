import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../api/api_client.dart';
import '../../../api/api_exceptions.dart';
import '../../../features/voice_capture/audio/audio_diag_log.dart';
import '../../../services/capture_attest_service.dart';
import '../domain/vault_chunk_payload.dart';

abstract class VaultUploadApiClient {
  Future<bool> uploadVaultChunk(VaultChunkPayload chunk);
}

class ApiVaultUploadApiClient implements VaultUploadApiClient {
  ApiVaultUploadApiClient({required this._api, required this._attest});

  final VoiceCaptureApiClient _api;
  final CaptureAttestService _attest;

  @override
  Future<bool> uploadVaultChunk(VaultChunkPayload chunk) async {
    try {
      final captureToken = await _attest.ensureCaptureToken();
      return _api.postVaultChunk(chunk: chunk, captureToken: captureToken);
    } on NetworkOfflineException catch (error, stackTrace) {
      _logFailure('transient_network', error, stackTrace);
      return false;
    } on AuthRequiredException catch (error, stackTrace) {
      _logFailure('authentication', error, stackTrace);
      return false;
    } on ApiException catch (error, stackTrace) {
      _logFailure(_apiFailureType(error), error, stackTrace);
      return false;
    } on SocketException catch (error, stackTrace) {
      _logFailure('transient_network', error, stackTrace);
      return false;
    } on TimeoutException catch (error, stackTrace) {
      _logFailure('transient_network', error, stackTrace);
      return false;
    } on http.ClientException catch (error, stackTrace) {
      _logFailure('transient_network', error, stackTrace);
      return false;
    } on Object catch (error, stackTrace) {
      _logFailure('unexpected', error, stackTrace);
      return false;
    }
  }

  static String _apiFailureType(ApiException error) {
    if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
      return 'authentication';
    }
    final status = error.statusCode ?? 0;
    if (status == 408 || status == 429 || status >= 500) {
      return 'transient_api';
    }
    return 'permanent_api';
  }

  static void _logFailure(
    String failureType,
    Object error,
    StackTrace stackTrace,
  ) {
    AudioDiagLog.failed(
      operation: 'emergency_vault_chunk_upload',
      failureType: failureType,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

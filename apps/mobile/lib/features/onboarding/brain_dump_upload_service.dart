import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/multipart_file_part.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';

/// Uploads encrypted onboarding brain-dump audio to the backend.
class BrainDumpUploadService {
  BrainDumpUploadService(this._transport);

  final HttpTransport _transport;

  Future<void> uploadEncryptedBrainDump({
    required File encryptedAudio,
    required String entryId,
    required int durationSeconds,
  }) async {
    final result = await _transport.postMultipart(
      VoiceMemoryApiRoutes.onboardingBrainDump.path,
      fields: {
        'entryId': entryId,
        'durationSeconds': '$durationSeconds',
      },
      files: [
        MultipartFilePart.fromPath(
          field: 'encryptedAudio',
          path: encryptedAudio.path,
          filename: encryptedAudio.uri.pathSegments.last,
        ),
      ],
    );

    return result.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiFailureMapper.fromResponse(response).toApiException();
        }
        return _transport.decodeEnvelopeOk(response).when(
          success: (_) {},
          onFailure: (failure) => throw failure.toApiException(),
        );
      },
      onFailure: (failure) => throw failure.toApiException(),
    );
  }
}

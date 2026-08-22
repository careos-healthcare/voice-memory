import 'dart:convert';

import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:archiveme_mobile/security/api_response_safety.dart';

/// Shared HTTP API surface for mobile archive flows.
class ApiService {
  ApiService(this._transport);

  final HttpTransport _transport;

  /// Records that the user rejected an evidence-backed insight pattern.
  Future<void> submitInsightCorrection({
    required String insightId,
    required PatternCorrectionReason reason,
  }) async {
    final result = await _transport.post(
      VoiceMemoryApiRoutes.insightsCorrections.path,
      body: {
        'insightId': insightId,
        'reason': reason.name,
      },
    );

    return result.when(
      success: (response) {
        try {
          ApiResponseSafety.ensureJsonResponse(response);
        } on ApiException catch (error, stackTrace) {
          throw ApiFailureMapper.fromException(error).toApiException();
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiFailureMapper.fromResponse(response).toApiException();
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final result = ApiEnvelopeAdapter.mapJsonOk(
          json: body,
          statusCode: response.statusCode,
        );
        return result.when(
          success: (_) {},
          onFailure: (failure) => throw failure.toApiException(),
        );
      },
      onFailure: (failure) => throw failure.toApiException(),
    );
  }
}
import 'package:archiveme_mobile/api/models/consent_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_consent_api.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/retrofit_providers.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_redemption_outcome.dart';
import 'package:dio/dio.dart';

/// Redeems a caregiver invitation against the server and, on success,
/// activates local caregiver mode via [CaregiverModeController].
///
/// Deliberately concrete (not behind the same abstract-seam pattern as
/// [CaregiverGrantIssuer]) — redemption is not behind a feature flag
/// requiring an "unwired" placeholder, and CaregiverGrantConsentAdapter
/// already establishes that code outside `lib/features/caregiver/` safely
/// imports and uses types from it directly.
class CaregiverRedemptionService {
  CaregiverRedemptionService({VoiceMemoryConsentApi? api}) : _api = api;

  final VoiceMemoryConsentApi? _api;

  Future<CaregiverRedemptionOutcome> redeemWithLinkToken(
    String linkToken,
  ) => _redeem({'linkToken': linkToken});

  Future<CaregiverRedemptionOutcome> redeemWithManualCode({
    required String reference,
    required String code,
  }) => _redeem({'reference': reference, 'code': code});

  Future<CaregiverRedemptionOutcome> _redeem(
    Map<String, dynamic> body,
  ) async {
    final ConsentRedeemResponseDto response;
    try {
      final VoiceMemoryConsentApi api = _api ??
          appProviderContainer.read(voiceMemoryConsentRetrofitApiProvider);
      response = await api.redeemToken(body);
    } on DioException catch (error) {
      return CaregiverRedemptionFailed(_messageFor(error));
    }
    final token = MonitoringConsentToken.fromJson(response.token);
    final result = await CaregiverModeController.instance.activateWithToken(
      token,
    );
    if (!result.valid) {
      return CaregiverRedemptionFailed(
        result.reason ?? 'Could not activate access on this device.',
      );
    }
    return const CaregiverRedemptionSucceeded();
  }

  String _messageFor(DioException error) {
    final data = error.response?.data;
    String? code;
    if (data is Map) {
      final errorField = data['error'];
      if (errorField is Map) {
        code = errorField['code']?.toString();
      }
    }
    return switch (code) {
      'REDEMPTION_NOT_FOUND' => 'This invitation link is not valid.',
      'REDEMPTION_EXPIRED' =>
        'This invitation has expired. Ask them to send a new one.',
      'REDEMPTION_LOCKED' =>
        'Too many incorrect attempts. Ask them to send a new invitation.',
      'REDEMPTION_CODE_MISMATCH' =>
        "That code doesn't match. Double-check and try again.",
      'REDEMPTION_ALREADY_USED' =>
        'This invitation has already been used.',
      'REDEMPTION_GRANT_REVOKED' =>
        'Access to this archive has been turned off.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}

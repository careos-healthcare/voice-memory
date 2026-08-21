import 'package:archiveme_mobile/api/retrofit/voice_memory_account_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_archive_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_auth_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_billing_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_consent_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_health_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_insights_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_ledger_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_live_audio_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_onboarding_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_push_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_relationships_api.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_sync_api.dart';
import 'package:dio/dio.dart';

/// Dio + Retrofit facade generated from `packages/api_contract/openapi.yaml`.
class VoiceMemoryRetrofitClient {
  VoiceMemoryRetrofitClient._({
    required this.dio,
    required this.auth,
    required this.billing,
    required this.capture,
    required this.sync,
    required this.liveAudio,
    required this.insights,
    required this.account,
    required this.push,
    required this.archive,
    required this.relationships,
    required this.consent,
    required this.ledger,
    required this.onboarding,
    required this.health,
  });

  final Dio dio;
  final VoiceMemoryAuthApi auth;
  final VoiceMemoryBillingApi billing;
  final VoiceMemoryCaptureApi capture;
  final VoiceMemorySyncApi sync;
  final VoiceMemoryLiveAudioApi liveAudio;
  final VoiceMemoryInsightsApi insights;
  final VoiceMemoryAccountApi account;
  final VoiceMemoryPushApi push;
  final VoiceMemoryArchiveApi archive;
  final VoiceMemoryRelationshipsApi relationships;
  final VoiceMemoryConsentApi consent;
  final VoiceMemoryLedgerApi ledger;
  final VoiceMemoryOnboardingApi onboarding;
  final VoiceMemoryHealthApi health;

  factory VoiceMemoryRetrofitClient.fromDio(Dio dio) {
    return VoiceMemoryRetrofitClient._(
      dio: dio,
      auth: VoiceMemoryAuthApi(dio),
      billing: VoiceMemoryBillingApi(dio),
      capture: VoiceMemoryCaptureApi(dio),
      sync: VoiceMemorySyncApi(dio),
      liveAudio: VoiceMemoryLiveAudioApi(dio),
      insights: VoiceMemoryInsightsApi(dio),
      account: VoiceMemoryAccountApi(dio),
      push: VoiceMemoryPushApi(dio),
      archive: VoiceMemoryArchiveApi(dio),
      relationships: VoiceMemoryRelationshipsApi(dio),
      consent: VoiceMemoryConsentApi(dio),
      ledger: VoiceMemoryLedgerApi(dio),
      onboarding: VoiceMemoryOnboardingApi(dio),
      health: VoiceMemoryHealthApi(dio),
    );
  }
}
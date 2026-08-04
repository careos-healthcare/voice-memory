import '../../api/api_client.dart';
import '../../audio/recording_service.dart';
import '../../billing/billing_platform.dart';
import '../../features/voice_capture/transcription/on_device_transcription_engine.dart';
import '../../features/voice_capture/transcription/transcription_connectivity.dart';
import '../../storage/secure_storage.dart';
import '../../subscriptions/data/subscription_data_sources.dart';
import '../../subscriptions/domain/subscription_repository.dart';

final class V1CompositionConfig {
  const V1CompositionConfig.production({required this.basePath})
    : testMode = false,
      journalPath = null,
      prefsPath = null,
      apiTransport = null,
      authApi = null,
      voiceCaptureApi = null,
      journalSyncApi = null,
      billingApi = null,
      subscriptionRepository = null,
      subscriptionStoreDataSource = null,
      subscriptionRemoteDataSource = null,
      subscriptionCacheDataSource = null,
      billingPlatform = null,
      skipBillingInitialization = false,
      recording = null,
      onDeviceTranscription = null,
      transcriptionConnectivity = const FixedTranscriptionConnectivity(true),
      secureStorage = null;

  const V1CompositionConfig.test({
    required this.basePath,
    required this.journalPath,
    this.prefsPath,
    this.apiTransport,
    this.authApi,
    this.voiceCaptureApi,
    this.journalSyncApi,
    this.billingApi,
    this.subscriptionRepository,
    this.subscriptionStoreDataSource,
    this.subscriptionRemoteDataSource,
    this.subscriptionCacheDataSource,
    this.billingPlatform,
    this.skipBillingInitialization = true,
    this.recording,
    this.onDeviceTranscription,
    this.transcriptionConnectivity = const FixedTranscriptionConnectivity(true),
    this.secureStorage,
  }) : testMode = true;

  final String basePath;
  final bool testMode;
  final String? journalPath;
  final String? prefsPath;
  final ApiTransport? apiTransport;
  final AuthApiClient? authApi;
  final VoiceCaptureApiClient? voiceCaptureApi;
  final JournalSyncApiClient? journalSyncApi;
  final BillingApiClient? billingApi;
  final SubscriptionRepository? subscriptionRepository;
  final SubscriptionStoreDataSource? subscriptionStoreDataSource;
  final SubscriptionRemoteDataSource? subscriptionRemoteDataSource;
  final SubscriptionCacheDataSource? subscriptionCacheDataSource;
  final BillingPlatform? billingPlatform;
  final bool skipBillingInitialization;
  final RecordingService? recording;
  final OnDeviceTranscriptionEngine? onDeviceTranscription;
  final TranscriptionConnectivity transcriptionConnectivity;
  final SecureStorageService? secureStorage;
}

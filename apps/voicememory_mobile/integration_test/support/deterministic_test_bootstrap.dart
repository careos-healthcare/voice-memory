import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/billing/billing_platform.dart';
import 'package:voicememory_mobile/billing/revenuecat_diagnostics.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/changes/change_thread_repository.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:voicememory_mobile/features/monetization/data/product_value_delivery_recorder.dart';
import 'package:voicememory_mobile/features/recording/domain/application/interpretation_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/on_device_transcription_engine.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_repository.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

import '../fixtures/core_scenarios.dart';

final class DeterministicCoreTestBootstrap {
  Directory? _fixtureRoot;

  int blockedTransportCalls = 0;
  late final DeterministicVoiceCaptureApi voiceProvider;
  late final DeterministicOnDeviceTranscription transcriptionProvider;
  late final DeterministicRecordingService recorderProvider;
  late final DeterministicRevenueCatProvider revenueCatProvider;

  Future<void> reset({bool onboardingComplete = true}) async {
    await dispose();
    ProductAnalytics.resetForTest();
    ChangeThreadRepository.resetForTest();
    WeeklyReviewRepository.resetForTest();
    ProductValueDeliveryRecorder.resetForTest();
    onboardingGate.resetForTest(complete: onboardingComplete);
    _fixtureRoot = await Directory.systemTemp.createTemp(
      'archiveme_core_integration_',
    );

    final transport = ApiTransport(
      baseUrl: 'https://integration.invalid',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/billing/entitlements') {
          return http.Response(
            '{"tier":"free","entitlements":[],"billingConnected":true,'
            '"source":"deterministic_integration_provider"}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        blockedTransportCalls += 1;
        return http.Response(
          '{"error":"network disabled in integration tests"}',
          503,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    voiceProvider = DeterministicVoiceCaptureApi(transport);
    transcriptionProvider = DeterministicOnDeviceTranscription();
    recorderProvider = DeterministicRecordingService(
      File('${_fixtureRoot!.path}/recorder_capture.wav'),
    );
    revenueCatProvider = DeterministicRevenueCatProvider();
    await AppConfig.initApiResolution();
    await AppServices.resetForTest(
      journalPath: '${_fixtureRoot!.path}/journal.json',
      prefsPath: '${_fixtureRoot!.path}/prefs.json',
      apiTransport: transport,
      voiceCaptureApi: voiceProvider,
      billingPlatform: revenueCatProvider,
      skipRevenueCat: true,
      recording: recorderProvider,
      onDeviceTranscription: transcriptionProvider,
      secureStorage: InMemorySecureStorageService(),
    );
    await InsightFeedbackStore.resetForTest();
    AppServices.instance.tokenCache.setToken(
      'deterministic-capture-token',
      expiresInSeconds: 3600,
    );
    await AppServices.instance.subscriptionRepository.refresh(force: true);
    if (onboardingComplete) onboardingGate.markComplete();
  }

  Future<void> pumpRealApp(WidgetTester tester, {String? location}) async {
    appRouter.go(location ?? RouteCatalog.recordHome);
    await tester.pumpWidget(const ArchiveMeApp());
    await pumpUntil(
      tester,
      () => find.byType(MaterialApp).evaluate().isNotEmpty,
      diagnostic: 'real app router did not mount',
    );
  }

  Future<void> prepareFirstRun() async {
    await AppServices.instance.prefs.setOnboardingCompleted(false);
    onboardingGate.resetForTest();
  }

  Future<File> createAudio([String name = 'capture.wav']) async {
    final file = File('${_fixtureRoot!.path}/$name');
    final bytes = List<int>.generate(8192, (index) => index % 251)
      ..setRange(0, 4, 'RIFF'.codeUnits)
      ..setRange(8, 12, 'WAVE'.codeUnits);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  DeterministicInterpretationRunner interpretationRunner() =>
      DeterministicInterpretationRunner();

  Future<void> dispose() async {
    if (AppServices.isInitialized) {
      await ProductValueDeliveryRecorder.settleForTest();
      await AppServices.disposeForTest();
    }
    final root = _fixtureRoot;
    _fixtureRoot = null;
    if (root != null && await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

final class DeterministicRecordingService extends RecordingService {
  DeterministicRecordingService(this.output) : super(testMode: true);

  final File output;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> startRecording({
    bool permissionVerified = false,
    int maxDurationSeconds = 300,
  }) async {
    startCalls += 1;
  }

  @override
  Future<RecordingResult> stopRecording() async {
    stopCalls += 1;
    final bytes = List<int>.generate(8192, (index) => index % 251)
      ..setRange(0, 4, 'RIFF'.codeUnits)
      ..setRange(8, 12, 'WAVE'.codeUnits);
    await output.writeAsBytes(bytes, flush: true);
    return RecordingResult(file: output, durationSeconds: 12);
  }
}

final class DeterministicRevenueCatProvider extends Fake
    implements BillingPlatform {
  static const _verifiedFree = PremiumEntitlements(
    tier: BillingTier.free,
    entitlementIds: [],
    billingConnected: true,
    source: 'deterministic_integration_provider',
  );

  int initializeCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get apiKeyMissing => false;

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      const Stream<PremiumEntitlements>.empty();

  @override
  PremiumEntitlements get latestEntitlements => _verifiedFree;

  @override
  RevenueCatDiagnostics get diagnostics => RevenueCatDiagnostics.initial();

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<String?> getAppUserId() async => null;

  @override
  Future<Offerings?> fetchOfferings() async => null;

  @override
  Future<PremiumEntitlements> refreshEntitlements() async => _verifiedFree;

  @override
  Future<PremiumEntitlements> syncAndRefreshEntitlements() async =>
      _verifiedFree;

  @override
  Future<PremiumEntitlements> restorePurchases() async => _verifiedFree;

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  void dispose() {}
}

final class DeterministicVoiceCaptureApi extends VoiceCaptureApiClient {
  DeterministicVoiceCaptureApi(super.transport);

  int transcribeCalls = 0;
  int analyzeCalls = 0;

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    transcribeCalls += 1;
    return CoreScenarioFixtures.voiceFirst;
  }

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    analyzeCalls += 1;
    final persisted = entryId == null
        ? null
        : await AppServices.instance.journalStore.getById(entryId);
    final entry =
        persisted ??
        JournalEntry(
          id: entryId ?? 'deterministic-entry',
          createdAt: DateTime.utc(2026, 8, 1),
          source: SavedMomentSource.typed,
          transcript: transcript,
          durationSeconds: 1,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 1,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        );
    final result = CoreScenarioFixtures.observationFor(
      entry,
      id: 'deterministic-observation-${entry.id}',
    );
    return result;
  }
}

final class DeterministicOnDeviceTranscription
    implements OnDeviceTranscriptionEngine {
  int transcribeCalls = 0;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async {
    transcribeCalls += 1;
    return CoreScenarioFixtures.voiceFirst;
  }
}

final class DeterministicInterpretationRunner
    implements InterpretationAnalysisRunner {
  int calls = 0;

  @override
  Future<Reflection> analyze(JournalEntry entry) async {
    calls += 1;
    return CoreScenarioFixtures.observationFor(entry);
  }
}

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String diagnostic,
}) async {
  for (var attempt = 0; attempt < 300 && !condition(); attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'REDACTED_DIAGNOSTIC: $diagnostic');
}

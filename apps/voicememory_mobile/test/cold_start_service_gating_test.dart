import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/billing/billing_platform.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/features/voice_capture/onboarding_microphone_state.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/composition/deferred_startup.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

/// Cold start must initialise only what Record needs to accept a tap.
///
/// The four deferred steps are asserted twice: once while the capture surface
/// is interactive (they must not have run) and once after activation (they must
/// have run, so nothing silently stopped working).
void main() {
  late Directory root;
  late _TrackedBillingPlatform billing;

  setUpAll(AppConfig.initApiResolution);

  setUp(() async {
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((_, _) {});
    ProductAnalytics.resetForTest();
    root = await Directory.systemTemp.createTemp('cold_start_gating_');
    billing = _TrackedBillingPlatform();
    await AppServices.resetForTest(
      journalPath: '${root.path}/journal.json',
      billingPlatform: billing,
      // The gating claim is only meaningful if a real initialize() would run.
      skipRevenueCat: false,
      recording: _ReadyRecordingService(),
    );
  });

  tearDown(() async {
    await AppServices.disposeForTest();
    ActivationFunnelAnalytics.resetForTest();
    ProductAnalytics.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  void expectDeferredWorkNotStarted({required String when}) {
    final composition = AppServices.instance.composition;
    expect(
      billing.initializeCalls,
      0,
      reason: 'billing SDK start-up must not run $when',
    );
    expect(
      composition.monetization.isActivated,
      isFalse,
      reason: 'monetization must not be activated $when',
    );
    expect(
      composition.analytics.isActivated,
      isFalse,
      reason: 'the analytics provider must not be initialised $when',
    );
    expect(
      composition.sync.isInitialized,
      isFalse,
      reason: 'the sync service must not be constructed $when',
    );
    expect(
      composition.archive.isSemanticIndexInitialized,
      isFalse,
      reason: 'the semantic index must not be opened $when',
    );
    expect(
      composition.deferredStartup.completedSteps,
      isEmpty,
      reason: 'no deferred step may have run $when',
    );
  }

  test('cold start registers the deferred steps without running them', () {
    final deferred = AppServices.instance.composition.deferredStartup;
    expect(deferred.registeredSteps, DeferredStartupStep.values.toSet());
    expect(deferred.pendingSteps, DeferredStartupStep.values.toSet());
    expectDeferredWorkNotStarted(when: 'during cold start');
  });

  testWidgets(
    'the capture surface reaches interactive with every deferred service still uninitialised',
    (tester) async {
      await tester.pumpWidget(_recordApp());

      // First frame: the Record action is already live.
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expectDeferredWorkNotStarted(when: 'before the first frame settles');

      // Let the surface finish its own async initialisation.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expect(
        find.byKey(const Key('record_idle_type_instead_cta')),
        findsOneWidget,
      );
      expectDeferredWorkNotStarted(when: 'once Record is interactive');
    },
  );

  testWidgets('the interactive capture surface has no account behind it', (
    tester,
  ) async {
    await tester.pumpWidget(_recordApp());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(
      AppServices.instance.composition.account.activeAccountId,
      isNull,
      reason: 'no account may be created before the first local save',
    );
    expectDeferredWorkNotStarted(when: 'on the guest capture surface');
  });

  test(
    'a guest-first local save works with no account and no deferred service',
    () async {
      final services = AppServices.instance;
      expect(services.composition.account.activeAccountId, isNull);

      await services.journalStore.save(_guestEntry());
      final stored = await services.journalStore.loadAll();

      expect(stored, hasLength(1));
      expect(stored.single.id, 'guest-entry');
      expect(services.composition.account.activeAccountId, isNull);
      expect(billing.initializeCalls, 0);
      expect(services.composition.monetization.isActivated, isFalse);
      expect(services.composition.analytics.isActivated, isFalse);
      expect(services.composition.sync.isInitialized, isFalse);
      // The semantic index is created by the journal's post-persist hook — after
      // the save, never before it.
      expect(services.composition.archive.isSemanticIndexInitialized, isTrue);
    },
  );

  test('deferred services all initialise after activation', () async {
    final composition = AppServices.instance.composition;
    expectDeferredWorkNotStarted(when: 'before activation');

    await AppServices.activateDeferredServices();

    expect(
      composition.deferredStartup.failures,
      isEmpty,
      reason: 'no deferred step may fail',
    );
    expect(
      composition.deferredStartup.completedSteps,
      DeferredStartupStep.values.toSet(),
    );
    expect(composition.deferredStartup.pendingSteps, isEmpty);
    expect(billing.initializeCalls, 1);
    expect(composition.monetization.isActivated, isTrue);
    expect(composition.analytics.isActivated, isTrue);
    expect(composition.sync.isInitialized, isTrue);
    expect(composition.archive.isSemanticIndexInitialized, isTrue);

    // Idempotent: a second activation must not re-initialise anything.
    await AppServices.activateDeferredServices();
    expect(billing.initializeCalls, 1);
  });

  test('sync still works on first use before activation', () {
    final composition = AppServices.instance.composition;
    expect(composition.sync.isInitialized, isFalse);

    // The facade getter must keep working for any pre-activation caller.
    expect(AppServices.instance.sync, isNotNull);
    expect(AppServices.instance.offlineSyncJourney, isNotNull);
    expect(composition.sync.isInitialized, isTrue);
  });

  test(
    'analytics recorded before provider activation is queued, not lost',
    () async {
      // A real provider is only installed by activation; until then the facade
      // buffers catalogued events.
      ActivationFunnelAnalytics.resetForTest();
      expect(ProductAnalytics.queuedEventCountForTest, 0);

      await ProductAnalytics.trackActivation(
        'first_capture_started',
        parameters: const {'performance_duration_band': 'under_200ms'},
      );

      expect(
        ProductAnalytics.queuedEventCountForTest,
        1,
        reason: 'a deferred provider must buffer, never drop',
      );

      final delivered = <String>[];
      ProductAnalytics.installProviderForTest((event, _) async {
        delivered.add(event);
      });
      await Future<void>.delayed(Duration.zero);

      expect(delivered, ['first_capture_started']);
    },
  );
}

Widget _recordApp() => MaterialApp(
  home: RecordScreen(
    microphonePermissionGateway: FakeMicrophonePermissionGateway(
      statusValue: PermissionStatus.granted,
    ),
    onboardingMicStateStore: OnboardingMicStateStore(
      AppServices.instance.prefs,
    ),
    openAppSettings: () async => true,
  ),
);

JournalEntry _guestEntry() => JournalEntry(
  id: 'guest-entry',
  createdAt: DateTime.utc(2026, 1, 1),
  transcript: 'A first moment saved without an account.',
  durationSeconds: 11,
  reflection: const Reflection(
    mood: 'steady',
    emotionalIntensity: 2,
    recurringThemes: ['starting'],
    exactLanguagePattern: 'without an account',
    concreteObservation: 'A first save completed locally.',
    repeatedSignal: '',
  ),
);

final class _TrackedBillingPlatform extends Fake implements BillingPlatform {
  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      const Stream<PremiumEntitlements>.empty();

  @override
  bool get isConfigured => false;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

/// A microphone that is already granted, so Record reaches its ready state
/// without any platform channel.
final class _ReadyRecordingService extends RecordingService {
  _ReadyRecordingService()
    : super(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.granted,
        ),
      );

  @override
  Future<MicPermissionResolution> evaluateMicrophonePermission() async =>
      const MicPermissionResolution(
        phase: RecordingPhase.ready,
        state: MicrophonePermissionState.granted,
        hasRecorder: true,
        permissionHandlerStatus: PermissionStatus.granted,
      );
}

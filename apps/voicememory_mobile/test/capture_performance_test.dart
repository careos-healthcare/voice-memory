import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/performance/capture_performance_analytics.dart';
import 'package:voicememory_mobile/features/performance/capture_performance_budgets.dart';
import 'package:voicememory_mobile/features/performance/capture_performance_tracker.dart';
import 'package:voicememory_mobile/features/performance/capture_span.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:voicememory_mobile/features/voice_capture/onboarding_microphone_state.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/analytics/analytics_catalog.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

/// Capture latency instrumentation: what it may report, and what it measures.
///
/// The measurement group is the source of every number in
/// `docs/current/PERFORMANCE_REPORT.md`. It runs on the host Dart VM under
/// `flutter test` (debug semantics, no device), which the report labels
/// explicitly.
void main() {
  setUpAll(AppConfig.initApiResolution);

  group('content-free instrumentation', () {
    late List<({CaptureSpan span, String band})> emitted;
    late CapturePerformanceTracker tracker;

    setUp(() {
      emitted = [];
      tracker = CapturePerformanceTracker(
        sink: (span, band) => emitted.add((span: span, band: band)),
      );
    });

    test('every band is a catalogued value at each boundary', () {
      const cases = <int, String>{
        0: 'under_200ms',
        199: 'under_200ms',
        200: 'under_500ms',
        499: 'under_500ms',
        500: 'under_1s',
        999: 'under_1s',
        1000: 'under_2s',
        1999: 'under_2s',
        2000: 'under_5s',
        4999: 'under_5s',
        5000: 'over_5s',
        60000: 'over_5s',
      };
      for (final entry in cases.entries) {
        final band = AnalyticsCatalog.durationBand(
          Duration(milliseconds: entry.key),
        );
        expect(band, entry.value, reason: '${entry.key}ms');
        expect(AnalyticsCatalog.performanceDurationBands, contains(band));
      }
    });

    test('each of the five spans emits exactly one catalogued band', () {
      tracker
        ..markAppLaunch()
        ..markRecordInteractive()
        ..markRecordTapped()
        ..markRecordingStarted()
        ..markStopTapped()
        ..markLocalSaveComplete()
        ..markTranscriptVisible()
        ..markFirstValidObservationVisible();

      expect(
        emitted.map((item) => item.span).toSet(),
        CaptureSpan.values.toSet(),
      );
      for (final item in emitted) {
        expect(AnalyticsCatalog.performanceDurationBands, contains(item.band));
      }
    });

    test('a band is reported at most once per app session', () {
      for (var i = 0; i < 4; i++) {
        tracker
          ..markRecordTapped()
          ..markRecordingStarted();
      }

      expect(
        emitted.where((item) => item.span == CaptureSpan.recordTapToRecording),
        hasLength(1),
      );
      // Every capture is still measured locally.
      expect(
        tracker.samplesFor(CaptureSpan.recordTapToRecording),
        hasLength(4),
      );
    });

    test('raw milliseconds stay local and never reach analytics', () async {
      ProductAnalytics.resetForTest();
      ActivationFunnelAnalytics.resetForTest();
      addTearDown(ProductAnalytics.resetForTest);

      final production = CapturePerformanceTracker()
        ..markStopTapped()
        ..markLocalSaveComplete();
      await Future<void>.delayed(Duration.zero);

      final events = ProductAnalytics.eventsForTest;
      expect(events, hasLength(1));
      expect(events.single.event, 'first_capture_saved');
      expect(events.single.parameters.keys, [
        CapturePerformanceAnalytics.propertyKey,
      ]);
      expect(
        AnalyticsCatalog.performanceDurationBands,
        contains(events.single.parameters.values.single),
      );

      final measured = production
          .samplesFor(CaptureSpan.stopTapToEncryptedPersistence)
          .single
          .milliseconds;
      for (final value in events.single.parameters.values) {
        expect(value, isNot('$measured'));
        expect(value, isNot('${measured}ms'));
        expect(
          RegExp(r'^\d+$').hasMatch('$value'),
          isFalse,
          reason: 'a bare number would be a raw timing',
        );
      }
    });

    test('every span reports through a registered V1 event id', () {
      for (final span in CaptureSpan.values) {
        final id = CapturePerformanceAnalytics.eventIds[span];
        expect(id, isNotNull, reason: span.id);
        expect(
          AnalyticsCatalog.activationEvent(id!),
          isNotNull,
          reason: 'unregistered event id "$id" would be rejected at runtime',
        );
      }
    });

    test('an abandoned capture records nothing', () {
      tracker
        ..markStopTapped()
        ..markCaptureAbandoned()
        ..markTranscriptVisible();

      expect(emitted, isEmpty);
      expect(tracker.samples, isEmpty);
    });

    test('a second local-save mark does not move the post-save clock', () {
      tracker
        ..markStopTapped()
        ..markLocalSaveComplete();
      final firstOpen = tracker.isOpen(CaptureSpan.saveToTranscriptVisible);

      expect(tracker.markLocalSaveComplete(), isNull);
      expect(firstOpen, isTrue);
      expect(
        tracker.samplesFor(CaptureSpan.stopTapToEncryptedPersistence),
        hasLength(1),
      );
    });
  });

  group('measured spans', () {
    late Directory root;
    late _ScriptedRecordingService recording;
    late CapturePerformanceTracker tracker;

    setUp(() async {
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest((_, _) {});
      ProductAnalytics.resetForTest();
      root = await Directory.systemTemp.createTemp('capture_performance_');
      recording = _ScriptedRecordingService(
        Directory('${root.path}/captures')..createSync(recursive: true),
      );
      await AppServices.resetForTest(
        journalPath: '${root.path}/journal.json',
        skipRevenueCat: true,
        recording: recording,
      );
      tracker = CapturePerformanceTracker(sink: (_, _) {});
      CapturePerformanceTracker.instance = tracker;
    });

    tearDown(() async {
      CapturePerformanceTracker.instance = CapturePerformanceTracker();
      // Derived-store work started inside a finished test's fake clock can
      // never complete, so disposal is bounded instead of awaited forever.
      await AppServices.disposeForTest().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
      ActivationFunnelAnalytics.resetForTest();
      ProductAnalytics.resetForTest();
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets('record surface reaches interactive, repeatedly', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      for (var i = 0; i < 5; i++) {
        tracker.markAppLaunch();
        await tester.pumpWidget(_recordApp(key: ValueKey('mount_$i')));
        await tester.pump();
        expect(
          find.byKey(const Key('capture_entry_record_cta')),
          findsOneWidget,
        );
        await _advance(tester, rounds: 200);
      }

      _report(CaptureSpan.appLaunchToRecordInteractive, tracker);
      final p50 = tracker.p50MillisecondsFor(
        CaptureSpan.appLaunchToRecordInteractive,
      );
      expect(p50, isNotNull);
      expect(
        p50,
        lessThanOrEqualTo(
          CapturePerformanceBudgets.budgetFor(
            CaptureSpan.appLaunchToRecordInteractive,
          ).inMilliseconds,
        ),
      );
    });

    testWidgets('record tap starts recording and stop seals the capture', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_recordApp());
      // Microphone state resolves once, before any measured tap, so the taps
      // below measure the app's own work and not a permission round trip.
      await _advance(tester, rounds: 200);

      const stop = Key('recording_stop_cta');
      const sheet = Key('post_capture_choice_sheet');
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('capture_entry_record_cta')));
        await _advanceUntilFound(tester, find.byKey(stop));
        expect(find.byKey(stop), findsOneWidget, reason: 'capture $i');

        await tester.tap(find.byKey(stop));
        await _advanceUntilFound(tester, find.byKey(sheet));
        expect(
          find.byKey(sheet),
          findsOneWidget,
          reason: 'the sheet only opens after the vault write and journal save',
        );
        await _chooseAudioOnly(tester);
      }

      // Unmount before asserting: the capture surface owns subscriptions and a
      // snackbar timer, and a disposed surface leaves the harness clean.
      await tester.pumpWidget(const SizedBox.shrink());
      await _advance(tester, rounds: 20);

      final entries = await tester.runAsync(
        AppServices.instance.journalStore.loadAll,
      );
      expect(entries, hasLength(5));
      for (final entry in entries!) {
        expect(
          entry.localAudioVaultRef,
          isNotNull,
          reason: 'every measured capture is sealed in the encrypted vault',
        );
      }

      for (final span in [
        CaptureSpan.recordTapToRecording,
        CaptureSpan.stopTapToEncryptedPersistence,
      ]) {
        _report(span, tracker);
        final p50 = tracker.p50MillisecondsFor(span);
        expect(p50, isNotNull, reason: '${span.id} produced no sample');
        expect(
          p50,
          lessThanOrEqualTo(
            CapturePerformanceBudgets.budgetFor(span).inMilliseconds,
          ),
        );
      }
    });

    testWidgets('save reaches a visible transcript and observation', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      for (var i = 0; i < 5; i++) {
        final entry = _observationEntry('measured_$i');
        await tester.runAsync(
          () => AppServices.instance.journalStore.save(entry),
        );
        // Mounting with a committed result marks the save, exactly as the
        // return from quick capture does.
        await tester.pumpWidget(
          _recordApp(
            key: ValueKey('saved_$i'),
            initialSavedResult: CapturePipelineResult(
              entry: entry,
              localSaved: true,
              syncSucceeded: false,
              analysisSucceeded: true,
            ),
          ),
        );
        // Both post-save marks land in the same frame, so the transcript
        // sample is the signal that the saved moment is on screen.
        await _advanceUntil(
          tester,
          () =>
              tracker.samplesFor(CaptureSpan.saveToTranscriptVisible).length >
              i,
        );
        expect(find.byKey(const Key('record_screen_scroll')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await _advance(tester, rounds: 20);

      _report(CaptureSpan.saveToTranscriptVisible, tracker);
      _report(CaptureSpan.saveToFirstValidObservation, tracker);

      for (final span in [
        CaptureSpan.saveToTranscriptVisible,
        CaptureSpan.saveToFirstValidObservation,
      ]) {
        final p50 = tracker.p50MillisecondsFor(span);
        expect(p50, isNotNull, reason: '${span.id} produced no sample');
        expect(
          p50,
          lessThanOrEqualTo(
            CapturePerformanceBudgets.budgetFor(span).inMilliseconds,
          ),
        );
      }
    });

    testWidgets(
      'shipping Record asks for interpretation after transcript review',
      (tester) async {
        _usePhoneSurface(tester);
        final entry = JournalEntry(
          id: 'fresh_interpretation_handoff',
          createdAt: DateTime.utc(2026, 8, 2),
          transcript: 'I paused before agreeing to another late meeting.',
          durationSeconds: 12,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        );
        await tester.runAsync(
          () => AppServices.instance.journalStore.save(entry),
        );

        await tester.pumpWidget(
          _recordApp(
            initialSavedResult: CapturePipelineResult(
              entry: entry,
              localSaved: true,
              syncSucceeded: false,
            ),
          ),
        );
        await _advanceUntilFound(
          tester,
          find.byKey(const Key('post_transcription_review_dialog')),
        );
        expect(
          find.byKey(const Key('post_transcription_review_dialog')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('post_transcription_review_continue')),
        );
        await _advanceUntilFound(
          tester,
          find.byKey(const Key('post_capture_interpretation_sheet')),
        );
        expect(find.text('Do you want a possible read?'), findsOneWidget);

        final decline = find.byKey(
          const Key('post_capture_interpretation_decline'),
        );
        await tester.ensureVisible(decline);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(decline);
        await _advanceUntil(
          tester,
          () => find
              .byKey(const Key('post_capture_interpretation_sheet'))
              .evaluate()
              .isEmpty,
        );
        await _advanceUntilFound(
          tester,
          find.byKey(const Key('post_save_saved_confirmation')),
        );

        final persisted = await tester.runAsync(
          () => AppServices.instance.journalStore.getById(entry.id),
        );
        expect(persisted, isNotNull);
        expect(
          persisted!.reflection.explainableConclusion,
          isNull,
          reason: 'declining interpretation must preserve the original only',
        );
      },
    );

    testWidgets('remote disclosure Type instead edits the saved voice entry', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      await tester.pumpWidget(_recordRouterApp());
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('capture_entry_record_cta')),
      );

      await tester.tap(find.byKey(const Key('capture_entry_record_cta')));
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('recording_stop_cta')),
      );
      await tester.tap(find.byKey(const Key('recording_stop_cta')));
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('post_capture_choice_sheet')),
      );

      final online = find.byKey(const Key('post_capture_choice_online'));
      await tester.ensureVisible(online);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(online);
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('remote_transcription_disclosure_dialog')),
      );
      await tester.tap(find.byKey(const Key('remote_disclosure_type_instead')));
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('quick_text_capture_field')),
      );

      await tester.enterText(
        find.byKey(const Key('quick_text_capture_field')),
        'I kept the recording and typed these words instead.',
      );
      final save = find.byKey(const Key('quick_text_capture_save'));
      await tester.ensureVisible(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await _advanceUntil(
        tester,
        () =>
            find
                .byKey(const Key('post_capture_interpretation_sheet'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const Key('quick_text_capture_error'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const Key('post_save_saved_confirmation'))
                .evaluate()
                .isNotEmpty,
      );
      expect(
        find.byKey(const Key('quick_text_capture_error')),
        findsNothing,
        reason: 'manual transcript attachment must remain local-first',
      );
      expect(
        find.byKey(const Key('post_save_saved_confirmation')),
        findsNothing,
        reason:
            'the post-save result must not bypass the interpretation question',
      );
      expect(
        find.byKey(const Key('post_capture_interpretation_sheet')),
        findsOneWidget,
        reason:
            'typed confirmation must return to the saved voice entry and ask '
            'the separate interpretation question',
      );
      final decline = find.byKey(
        const Key('post_capture_interpretation_decline'),
      );
      await tester.ensureVisible(decline);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(decline);
      await _advanceUntilFound(
        tester,
        find.byKey(const Key('post_save_saved_confirmation')),
      );

      final entries = await tester.runAsync(
        AppServices.instance.journalStore.loadAll,
      );
      expect(entries, hasLength(1));
      expect(entries!.single.localAudioVaultRef, isNotEmpty);
      expect(
        entries.single.transcript,
        'I kept the recording and typed these words instead.',
      );
    });
  });

  group('cold start service graph', () {
    test(
      'deferring the non-capture modules measurably shortens cold start',
      () async {
        final deferredMs = <int>[];
        final eagerMs = <int>[];

        for (var i = 0; i < 5; i++) {
          deferredMs.add(await _timeColdStart(activateDeferred: false));
          eagerMs.add(await _timeColdStart(activateDeferred: true));
        }

        deferredMs.sort();
        eagerMs.sort();
        final deferredP50 = deferredMs[deferredMs.length ~/ 2];
        final eagerP50 = eagerMs[eagerMs.length ~/ 2];
        debugPrint(
          'MEASURED cold_start_service_graph '
          'deferred_p50=${deferredP50}ms all=$deferredMs',
        );
        debugPrint(
          'MEASURED cold_start_service_graph '
          'with_deferred_work_p50=${eagerP50}ms all=$eagerMs',
        );
        expect(deferredP50, lessThanOrEqualTo(eagerP50));
      },
    );
  });
}

Future<int> _timeColdStart({required bool activateDeferred}) async {
  final root = await Directory.systemTemp.createTemp('cold_start_timing_');
  final stopwatch = Stopwatch()..start();
  await AppServices.resetForTest(
    journalPath: '${root.path}/journal.json',
    skipRevenueCat: true,
  );
  if (activateDeferred) await AppServices.activateDeferredServices();
  stopwatch.stop();
  await AppServices.disposeForTest();
  if (await root.exists()) await root.delete(recursive: true);
  return stopwatch.elapsedMilliseconds;
}

void _report(CaptureSpan span, CapturePerformanceTracker tracker) {
  debugPrint(
    'MEASURED ${span.id} '
    'n=${tracker.samplesFor(span).length} '
    'p50=${tracker.p50MillisecondsFor(span)}ms '
    'p95=${tracker.p95MillisecondsFor(span)}ms '
    'max=${tracker.maxMillisecondsFor(span)}ms '
    'raw=${tracker.samplesFor(span).map((s) => s.milliseconds).toList()}',
  );
}

/// A phone-shaped surface, so the post-capture sheet lays out the way it does
/// on a device instead of overflowing the default 800x600 test window.
void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Lets real asynchronous work run inside a widget test, then paints it.
///
/// A widget test runs on a fake clock that also queues microtasks, so an app
/// future waiting on real file, preference or vault I/O advances by exactly one
/// hop per `pump`. Each round therefore hands the event loop back briefly — long
/// enough for a completed I/O reply to arrive — and then pumps once. Rounds are
/// deliberately cheap so a measured span stays close to the app's own cost
/// rather than to the harness's polling interval.
Future<void> _advance(WidgetTester tester, {int rounds = 1}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() async {
      for (var yields = 0; yields < 4; yields++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _advanceUntil(
  WidgetTester tester,
  bool Function() satisfied, {
  int maxRounds = 4000,
}) async {
  for (var round = 0; round < maxRounds && !satisfied(); round++) {
    await _advance(tester);
  }
}

Future<void> _advanceUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxRounds = 4000,
}) => _advanceUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  maxRounds: maxRounds,
);

Future<void> _chooseAudioOnly(WidgetTester tester) async {
  const sheet = Key('post_capture_choice_sheet');
  final option = find.byKey(const Key('post_capture_choice_audio_only'));
  if (option.evaluate().isEmpty) return;
  // The sheet exists one frame before it has slid into place. The measured span
  // ended when the sheet was requested, so waiting out its animation here costs
  // the measurement nothing.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(option);
  // The Record action sits underneath the sheet, so the sheet leaving is the
  // only reliable signal that the next capture may begin.
  await _advanceUntil(tester, () => find.byKey(sheet).evaluate().isEmpty);
  await _advanceUntilFound(
    tester,
    find.byKey(const Key('capture_entry_record_cta')),
  );
}

Widget _recordApp({Key? key, CapturePipelineResult? initialSavedResult}) =>
    MaterialApp(
      home: RecordScreen(
        key: key,
        microphonePermissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.granted,
        ),
        onboardingMicStateStore: OnboardingMicStateStore(
          AppServices.instance.prefs,
        ),
        openAppSettings: () async => true,
        initialSavedResult: initialSavedResult,
      ),
    );

Widget _recordRouterApp() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => RecordScreen(
          microphonePermissionGateway: FakeMicrophonePermissionGateway(
            statusValue: PermissionStatus.granted,
          ),
          onboardingMicStateStore: OnboardingMicStateStore(
            AppServices.instance.prefs,
          ),
          openAppSettings: () async => true,
        ),
      ),
      GoRoute(
        path: '/quick-capture',
        builder: (_, state) {
          final extra = state.extra;
          final options = extra is Map ? extra : const <Object?, Object?>{};
          return QuickTextCaptureScreen(
            entryId: options['entryId'] as String?,
            focusedRecordTypeEntry: options['focusedRecordTypeEntry'] == true,
          );
        },
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// An entry whose persisted observation survives the trust policy, so the
/// post-save surface has a real conclusion to render.
JournalEntry _observationEntry(String id) {
  const transcript = 'I checked the finished report again before sending it.';
  final at = DateTime.utc(2026, 8, 1, 9);
  final conclusion = ExplainableConclusion(
    id: 'observation-$id',
    statement: 'You described checking the finished report again.',
    confidence: 60,
    reasoning: const [
      'The saved words describe checking the finished report again.',
    ],
    uncertaintyNote: 'One moment cannot show whether this response repeats.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: id,
        quote: transcript,
        startUtf16: 0,
        endUtf16: transcript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: at,
        sourceType: EvidenceSourceType.voice,
        audioVaultReference: 'vault-$id',
        audioTimestampMs: 1200,
        audioEndTimestampMs: 4400,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'This may be specific to this one report.',
        rationale: 'ArchiveMe has only one supporting saved moment so far.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: at.add(const Duration(minutes: 1)),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
    nextRecordingPrompt: 'When the report is ready next time, what do you do?',
  );
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 20,
    localAudioVaultRef: 'vault-$id',
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: transcript,
      concreteObservation: conclusion.statement,
      repeatedSignal: '',
      explainableConclusion: conclusion,
    ),
  );
}

/// A recorder that produces a real, vault-sized capture file without any
/// platform channel, so the measured work is the app's own.
final class _ScriptedRecordingService extends RecordingService {
  _ScriptedRecordingService(this.workingDirectory)
    : super(
        testMode: true,
        permissionGateway: FakeMicrophonePermissionGateway(
          statusValue: PermissionStatus.granted,
        ),
      );

  final Directory workingDirectory;
  int _captureCount = 0;

  @override
  Future<MicPermissionResolution> evaluateMicrophonePermission() async =>
      const MicPermissionResolution(
        phase: RecordingPhase.ready,
        state: MicrophonePermissionState.granted,
        hasRecorder: true,
        permissionHandlerStatus: PermissionStatus.granted,
      );

  @override
  Future<void> startRecording({
    bool permissionVerified = false,
    int maxDurationSeconds = 600,
  }) async {}

  @override
  Future<RecordingResult> stopRecording() async {
    _captureCount++;
    final file = File('${workingDirectory.path}/capture_$_captureCount.m4a');
    final bytes = List<int>.generate(4096, (index) => index % 251)
      ..setRange(4, 8, 'ftyp'.codeUnits);
    await file.writeAsBytes(bytes, flush: true);
    return RecordingResult(file: file, durationSeconds: 12);
  }
}

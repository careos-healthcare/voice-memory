import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/journal_sync_api_client.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/changes/change_thread_repository.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync_key_store.dart';
import 'package:voicememory_mobile/features/monetization/data/product_value_delivery_recorder.dart';
import 'package:voicememory_mobile/features/monetization/domain/product_value_delivery_ledger.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_screen.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_service.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_review_repository.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';
import 'package:voicememory_mobile/screens/export_screen.dart';
import 'package:voicememory_mobile/services/analytics/operational_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/widgets/record/compact_auditable_conclusion_card.dart';

import 'fixtures/core_scenarios.dart';
import 'support/deterministic_test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DeterministicCoreTestBootstrap fixture;

  setUp(() async {
    fixture = DeterministicCoreTestBootstrap();
    await fixture.reset();
  });

  tearDown(() async {
    ProductAnalytics.resetForTest();
    ChangeThreadRepository.resetForTest();
    WeeklyReviewRepository.resetForTest();
    ProductValueDeliveryRecorder.resetForTest();
    await fixture.dispose();
  });

  _coreTestWidgets(
    '01 first run types, reviews, consents and sees exact first proof',
    (tester) async {
      await fixture.prepareFirstRun();
      await fixture.pumpRealApp(tester);
      await _waitFor(tester, const Key('onboarding_promise_screen'));

      await tester.tap(find.byKey(const Key('onboarding_type_instead_cta')));
      await _waitFor(tester, const Key('quick_text_capture_field'));
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.typedFirst,
        generateInterpretation: true,
      );

      expect(find.byType(CompactAuditableConclusionCard), findsOneWidget);
      expect(find.text('“${CoreScenarioFixtures.typedFirst}”'), findsOneWidget);
      await pumpUntil(
        tester,
        () => ProductValueDeliveryRecorder.cached.hasDelivered(
          DeliveredValueKind.observation,
        ),
        diagnostic: 'first proof was rendered but not durably delivered',
      );
      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, hasLength(1));
      expect(entries.single.source, SavedMomentSource.typed);
      expect(entries.single.transcript, CoreScenarioFixtures.typedFirst);
      expect(
        entries.single.reflection.explainableConclusion!.evidence.single.quote,
        CoreScenarioFixtures.typedFirst,
      );
      expect(fixture.voiceProvider.analyzeCalls, 1);
      expect(
        ProductValueDeliveryRecorder.cached.hasDelivered(
          DeliveredValueKind.observation,
        ),
        isTrue,
      );
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '02 voice UI preserves audio and provenance through first proof',
    (tester) async {
      await fixture.pumpRealApp(tester);
      await _waitFor(tester, const Key('capture_entry_record_cta'));

      await tester.tap(find.byKey(const Key('capture_entry_record_cta')));
      await _waitFor(tester, const Key('recording_stop_cta'));
      await tester.tap(find.byKey(const Key('recording_stop_cta')));
      await _waitFor(tester, const Key('post_capture_choice_sheet'));
      await _tapVisible(
        tester,
        find.byKey(const Key('post_capture_choice_on_device')),
      );
      await _waitFor(tester, const Key('post_transcription_review_dialog'));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('post_transcription_review_field')),
            )
            .controller!
            .text,
        CoreScenarioFixtures.voiceFirst,
      );
      await tester.tap(
        find.byKey(const Key('post_transcription_review_continue')),
      );
      await _chooseGenerateAndConsent(tester);
      await _waitFor(tester, const Key('post_save_compact_conclusion'));

      final entry = (await AppServices.instance.journalStore.loadAll()).single;
      expect(entry.source, SavedMomentSource.voice);
      expect(entry.localAudioVaultRef, isNotNull);
      expect(
        await AppServices.instance.journalAudioVault.exists(
          entry.localAudioVaultRef!,
        ),
        isTrue,
      );
      final citation = entry.reflection.explainableConclusion!.evidence.single;
      expect(citation.sourceType, EvidenceSourceType.voice);
      expect(citation.audioVaultReference, entry.localAudioVaultRef);
      expect(fixture.recorderProvider.startCalls, 1);
      expect(fixture.recorderProvider.stopCalls, 1);
      expect(fixture.transcriptionProvider.transcribeCalls, 1);
      expect(fixture.voiceProvider.analyzeCalls, 1);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '03 decline UI keeps free proof open and exposes later-analysis CTA',
    (tester) async {
      await fixture.pumpRealApp(tester);
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.typedFirst,
        generateInterpretation: false,
      );

      expect(
        find.byKey(const Key('focused_auditable_no_conclusion')),
        findsOneWidget,
      );
      expect(
        ProductValueDeliveryRecorder.cached.hasDelivered(
          DeliveredValueKind.observation,
        ),
        isFalse,
      );
      expect(fixture.voiceProvider.analyzeCalls, 0);
      await tester.tap(find.byKey(const Key('post_save_open_saved_moment')));
      await _waitFor(tester, const Key('entry_detail_generate_read'));
      expect(find.text('Generate a possible read'), findsOneWidget);
      expect(
        (await AppServices.instance.journalStore.loadAll())
            .single
            .reflection
            .explainableConclusion,
        isNull,
      );
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '04 online disclosure Type instead continues one existing voice entry',
    (tester) async {
      await fixture.pumpRealApp(tester);
      await _waitFor(tester, const Key('capture_entry_record_cta'));
      await tester.tap(find.byKey(const Key('capture_entry_record_cta')));
      await _waitFor(tester, const Key('recording_stop_cta'));
      await tester.tap(find.byKey(const Key('recording_stop_cta')));
      await _waitFor(tester, const Key('post_capture_choice_sheet'));
      await _tapVisible(
        tester,
        find.byKey(const Key('post_capture_choice_online')),
      );
      await _waitFor(
        tester,
        const Key('remote_transcription_disclosure_dialog'),
      );
      expect(find.text('Online transcription'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const Key('remote_disclosure_type_instead')),
      );
      await _waitFor(tester, const Key('quick_text_capture_field'));
      await tester.enterText(
        find.byKey(const Key('quick_text_capture_field')),
        CoreScenarioFixtures.typedInstead,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('quick_text_capture_save')),
      );
      await _waitFor(tester, const Key('post_capture_interpretation_sheet'));
      await _tapVisible(
        tester,
        find.byKey(const Key('post_capture_interpretation_decline')),
      );
      await _waitFor(tester, const Key('focused_auditable_post_save_section'));

      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, hasLength(1));
      expect(entries.single.source, SavedMomentSource.voice);
      expect(entries.single.transcript, CoreScenarioFixtures.typedInstead);
      expect(entries.single.localAudioVaultRef, isNotNull);
      expect(
        await AppServices.instance.journalAudioVault.exists(
          entries.single.localAudioVaultRef!,
        ),
        isTrue,
      );
      expect(fixture.voiceProvider.transcribeCalls, 0);
      expect(fixture.voiceProvider.analyzeCalls, 0);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '05 Entry Detail Generate drives choice, disclosure and later proof',
    (tester) async {
      final saved = await AppServices.instance.pipeline.saveTextThought(
        transcript: CoreScenarioFixtures.voiceFirst,
        currentInterpretationChoice:
            InterpretationPreference.saveWithoutInterpretation,
      );
      await fixture.pumpRealApp(tester, location: '/entry/${saved.entry.id}');
      await _waitFor(tester, const Key('entry_detail_generate_read'));

      await tester.tap(find.byKey(const Key('entry_detail_generate_read')));
      await _chooseGenerateAndConsent(tester);
      await _waitFor(tester, const Key('post_save_compact_conclusion'));

      expect(find.byKey(const Key('entry_detail_generate_read')), findsNothing);
      final persisted = await AppServices.instance.journalStore.getById(
        saved.entry.id,
      );
      expect(persisted!.id, saved.entry.id);
      expect(persisted.transcript, CoreScenarioFixtures.voiceFirst);
      expect(persisted.reflection.explainableConclusion, isNotNull);
      expect(fixture.voiceProvider.analyzeCalls, 1);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '06 production correction controls persist metadata without content analytics',
    (tester) async {
      final controls = <(String, InsightFeedbackChoice)>[
        ('post_save_feedback_accurate', InsightFeedbackChoice.accurate),
        ('post_save_feedback_wrong_angle', InsightFeedbackChoice.wrongAngle),
        ('post_save_feedback_too_generic', InsightFeedbackChoice.tooGeneric),
        ('post_save_feedback_hide', InsightFeedbackChoice.hide),
      ];
      final seeded = <JournalEntry>[];
      for (var index = 0; index < controls.length; index++) {
        final entry = _entry(
          id: 'feedback-$index',
          at: DateTime.utc(2026, 8, 1, 9, index),
          transcript: index.isEven
              ? CoreScenarioFixtures.typedFirst
              : CoreScenarioFixtures.voiceFirst,
        );
        final reflection = CoreScenarioFixtures.observationFor(
          entry,
          id: 'feedback-conclusion-$index',
        );
        final persisted = _entry(
          id: entry.id,
          at: entry.createdAt,
          transcript: entry.transcript,
          reflection: reflection,
        );
        await AppServices.instance.journalStore.save(persisted);
        seeded.add(persisted);
      }

      for (var index = 0; index < controls.length; index++) {
        final (key, choice) = controls[index];
        appRouter.go('/entry/${seeded[index].id}');
        if (index == 0) {
          await tester.pumpWidget(const ArchiveMeApp());
        }
        await _waitForFinder(
          tester,
          find.text('“${seeded[index].transcript}”'),
          diagnostic: 'entry detail did not switch to the requested fixture',
        );
        await _waitFor(tester, const Key('post_save_compact_conclusion'));
        await _tapVisible(tester, find.byKey(Key(key)));
        if (choice == InsightFeedbackChoice.wrongAngle) {
          await _waitFor(tester, const Key('post_save_correction_input'));
          await tester.enterText(
            find.byKey(const Key('post_save_correction_input')),
            CoreScenarioFixtures.privateCorrection,
          );
          await tester.tap(find.text('Save correction'));
        }
        await pumpUntil(
          tester,
          () => InsightFeedbackStore.cached.any(
            (record) =>
                record.insightId == 'feedback-conclusion-$index' &&
                record.choice == choice,
          ),
          diagnostic: 'correction control did not persist metadata',
        );
      }

      final records = await InsightFeedbackStore(
        AppServices.instance.prefs,
      ).loadAll();
      expect(
        records.map((record) => record.choice).toSet(),
        containsAll({
          InsightFeedbackChoice.accurate,
          InsightFeedbackChoice.wrongAngle,
          InsightFeedbackChoice.tooGeneric,
          InsightFeedbackChoice.hide,
        }),
      );
      final analytics = ProductAnalytics.eventsForTest
          .map((event) => '${event.event} ${event.parameters}')
          .join(' ');
      for (final entry in seeded) {
        expect(analytics, isNot(contains(entry.transcript)));
        expect(
          analytics,
          isNot(contains(entry.reflection.explainableConclusion!.statement)),
        );
      }
      expect(
        analytics,
        isNot(contains(CoreScenarioFixtures.privateCorrection)),
      );
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '07 two genuinely related UI saves render one ordered comparison',
    (tester) async {
      await fixture.pumpRealApp(tester);
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.thenQuote,
        generateInterpretation: false,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('focused_auditable_record_next')),
      );
      await _waitFor(tester, const Key('record_idle_type_instead_cta'));
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.nowQuote,
        generateInterpretation: false,
        expectConclusion: true,
      );

      expect(
        find.byKey(const Key('post_save_compact_conclusion')),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('post_save_check_all_evidence')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Then'), findsWidgets);
      expect(find.textContaining('Now'), findsWidgets);
      expect(find.textContaining(CoreScenarioFixtures.thenQuote), findsWidgets);
      expect(find.textContaining(CoreScenarioFixtures.nowQuote), findsWidgets);

      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, hasLength(2));
      final comparison = tester
          .widget<CompactAuditableConclusionCard>(
            find.byType(CompactAuditableConclusionCard),
          )
          .conclusion
          .value;
      expect(comparison.kind, ExplainableInsightKind.change);
      expect(comparison.evidence, hasLength(2));
      expect(
        comparison.evidence.first.sourceCapturedAt!.isBefore(
          comparison.evidence.last.sourceCapturedAt!,
        ),
        isTrue,
      );
      expect(
        comparison.evidence.map((citation) => citation.entryId).toSet(),
        hasLength(2),
      );
      expect(
        comparison.evidence.map((citation) => citation.quote).toSet(),
        hasLength(2),
      );
      expect(fixture.voiceProvider.analyzeCalls, 0);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '08 Changes UI supports Then/Now, rename, source nav and unrelated suppression',
    (tester) async {
      await fixture.pumpRealApp(tester);
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.thenQuote,
        generateInterpretation: false,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('focused_auditable_record_next')),
      );
      await _waitFor(tester, const Key('record_idle_type_instead_cta'));
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.nowQuote,
        generateInterpretation: false,
        expectConclusion: true,
      );
      await pumpUntil(
        tester,
        () => ProductValueDeliveryRecorder.cached.hasDelivered(
          DeliveredValueKind.comparison,
        ),
        diagnostic: 'comparison was not durably delivered',
      );
      final beforeUnrelated =
          (await ChangeThreadRepository.load()).projection.threads.length;
      expect(beforeUnrelated, 1);
      await _tapVisible(
        tester,
        find.byKey(const Key('post_save_check_all_evidence')),
      );
      await _waitFor(tester, const Key('post_save_evidence_detail_sheet'));
      final detailRecordNext = find.byKey(
        const Key('post_save_detail_record_next'),
      );
      await tester.scrollUntilVisible(
        detailRecordNext,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('post_save_evidence_detail_sheet')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _tapVisible(tester, detailRecordNext);
      await _waitFor(tester, const Key('record_idle_type_instead_cta'));
      await _startTypedFromRecord(tester);
      await _finishTypedCapture(
        tester,
        text: CoreScenarioFixtures.unrelated,
        generateInterpretation: false,
      );
      expect(
        find.byKey(const Key('post_save_compact_conclusion')),
        findsNothing,
      );
      final afterUnrelated = await ChangeThreadRepository.load();
      expect(afterUnrelated.projection.threads, hasLength(beforeUnrelated));
      expect(
        (await AppServices.instance.journalStore.loadAll()).any(
          (entry) => entry.transcript == CoreScenarioFixtures.unrelated,
        ),
        isTrue,
      );

      appRouter.go(RouteCatalog.changesHome);
      await tester.pump();
      ChangesSnapshot snapshot = await ChangeThreadRepository.load();
      for (
        var attempt = 0;
        attempt < 100 && snapshot.projection.threads.isEmpty;
        attempt++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 5));
        snapshot = await ChangeThreadRepository.load();
      }
      expect(snapshot.projection.threads, hasLength(1));
      final threadId = snapshot.projection.threads.single.thread.threadId;
      final openThread = find.byKey(ValueKey('change_thread_open_$threadId'));
      await _waitForFinder(
        tester,
        openThread,
        diagnostic: 'Changes did not render the persisted comparison',
      );
      await tester.tap(openThread);
      await tester.pumpAndSettle();
      expect(find.textContaining('Then ·'), findsOneWidget);
      expect(find.textContaining('Now ·'), findsOneWidget);
      expect(find.text('“${CoreScenarioFixtures.thenQuote}”'), findsOneWidget);
      expect(find.text('“${CoreScenarioFixtures.nowQuote}”'), findsOneWidget);

      await tester.tap(find.byKey(const Key('change_thread_corrections')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename this thread'));
      await _waitFor(tester, const Key('change_thread_rename_field'));
      await tester.enterText(
        find.byKey(const Key('change_thread_rename_field')),
        'Work response',
      );
      await tester.tap(find.text('Save'));
      await _waitForFinder(
        tester,
        find.text('Work response'),
        diagnostic: 'thread rename did not return to production Changes UI',
      );
      await tester.pumpAndSettle();

      final openSource = find.widgetWithText(TextButton, 'Open exact moment');
      if (openSource.evaluate().isEmpty) {
        await _waitForFinder(
          tester,
          openThread,
          diagnostic: 'renamed thread was not available to reopen',
        );
        await _tapVisible(tester, openThread);
        await tester.pumpAndSettle();
      }
      await _waitForFinder(
        tester,
        openSource,
        diagnostic: 'reopened thread did not expose source navigation',
      );
      await _tapVisible(tester, openSource.first);
      await pumpUntil(
        tester,
        () => appRouter.routeInformationProvider.value.uri.path.startsWith(
          '/entry/',
        ),
        diagnostic: 'Then source did not navigate to its exact entry',
      );
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '09 weekly review opens inside Changes with bounded exact evidence',
    (tester) async {
      final then = _entry(
        id: 'weekly-then',
        at: DateTime.utc(2026, 8, 1, 9),
        transcript: CoreScenarioFixtures.thenQuote,
      );
      final now = _entry(
        id: 'weekly-now',
        at: DateTime.utc(2026, 8, 3, 9),
        transcript: CoreScenarioFixtures.nowQuote,
      );
      final conclusion = _changeConclusion(then, now);
      final nowWithConclusion = _entry(
        id: now.id,
        at: now.createdAt,
        transcript: now.transcript,
        reflection: Reflection(
          mood: now.reflection.mood,
          emotionalIntensity: now.reflection.emotionalIntensity,
          recurringThemes: now.reflection.recurringThemes,
          exactLanguagePattern: now.reflection.exactLanguagePattern,
          concreteObservation: now.reflection.concreteObservation,
          repeatedSignal: now.reflection.repeatedSignal,
          explainableConclusion: conclusion,
        ),
      );
      await AppServices.instance.journalStore.save(then);
      await AppServices.instance.journalStore.save(nowWithConclusion);
      final projection = ChangeThreadProjector.project(
        archiveId: AppServices.instance.journalStore.ownerArchiveId,
        entries: [then, nowWithConclusion],
        conclusions: [conclusion],
      );
      expect(projection.threads, hasLength(1));
      await ChangeThreadRepository.storeOrNull()!.save(projection);
      final view = projection.threads.single;
      final event = view.events.single;
      final review = WeeklyReview(
        reviewId: 'weekly_review_deterministic',
        windowStart: DateTime.utc(2026, 7, 28),
        windowEnd: DateTime.utc(2026, 8, 4),
        generatedAt: DateTime.utc(2026, 8, 4, 5),
        items: [
          WeeklyReviewItem(
            kind: WeeklyReviewItemKind.possibleChange,
            threadId: view.thread.threadId,
            threadLabel: view.thread.userEditableLabel,
            eventId: event.eventId,
            statement: event.statement,
            evidence: event.exactEvidence,
            occurredAt: event.occurredAt,
          ),
        ],
      );
      await WeeklyReviewRepository.storeOrNull()!.saveReview(review);

      await fixture.pumpRealApp(tester, location: RouteCatalog.changesHome);
      await _waitFor(tester, const Key('weekly_review_entry_card'));
      await tester.tap(find.byKey(const Key('weekly_review_entry_card')));
      await _waitFor(tester, const Key('weekly_review_screen_headline'));

      expect(review.items, hasLength(lessThanOrEqualTo(3)));
      expect(review.items.single.evidence, isNotEmpty);
      final reviewDetail = find.byKey(
        const Key('weekly_review_item_possibleChange'),
      );
      expect(
        find.descendant(
          of: reviewDetail,
          matching: find.text('“${CoreScenarioFixtures.thenQuote}”'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: reviewDetail,
          matching: find.text('“${CoreScenarioFixtures.nowQuote}”'),
        ),
        findsOneWidget,
      );
      expect(find.text('Open in Changes'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '10 readable and full export generate and hand off without OS share UI',
    (tester) async {
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'export-entry',
          at: DateTime.utc(2026, 8, 4),
          transcript: CoreScenarioFixtures.typedFirst,
        ),
      );
      final temp = await Directory.systemTemp.createTemp(
        'archiveme_export_integration_',
      );
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final handoffs =
          <({String subject, List<String> names, String payload})>[];
      final dependencies = ExportScreenDependencies(
        temporaryDirectory: () async => temp,
        appVersion: () async => 'integration+1',
        handoff: (files, subject) async {
          handoffs.add((
            subject: subject,
            names: files.map((file) => file.path.split('/').last).toList(),
            payload: (await Future.wait(
              files.map((file) => file.readAsBytes()),
            )).map(base64Encode).join(),
          ));
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: ExportScreen(dependencies: dependencies)),
      );

      await tester.tap(find.byKey(const Key('export_readable_archive')));
      await pumpUntil(
        tester,
        () => handoffs.length == 1,
        diagnostic: 'readable archive was not handed to the injected boundary',
      );
      await tester.pumpAndSettle();
      expect(
        handoffs.single.names,
        containsAll(['archiveme_archive.md', 'archiveme_archive.json']),
      );
      expect(handoffs.single.payload, isNotEmpty);
      expect(find.textContaining('Audio bytes were excluded'), findsOneWidget);

      await tester.tap(find.byKey(const Key('export_full_archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_full_audio_export')));
      await pumpUntil(
        tester,
        () => handoffs.length == 2,
        diagnostic: 'full archive was not handed to the injected boundary',
      );
      await tester.pumpAndSettle();
      expect(handoffs.last.names.single, endsWith('.zip'));
      expect(handoffs.last.payload, isNotEmpty);
      expect(find.textContaining('Full archive ready'), findsOneWidget);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '11 recovery setup exact re-entry and fresh-device recovery stay local',
    (tester) async {
      final api = _DeterministicRecoveryApi();
      final originalStorage = InMemorySecureStorageService();
      final originalKeyStore = SavedMomentSyncKeyStore(originalStorage);
      final identity = _authenticatedIdentity('archive-original');
      final setupService = SyncRecoveryService(
        api: api,
        keyStore: originalKeyStore,
        identityProvider: () => identity,
      );
      await tester.pumpWidget(
        MaterialApp(home: SyncRecoveryScreen(service: setupService)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sync_recovery_setup')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final code = tester
          .widget<SelectableText>(
            find.byKey(const Key('sync_recovery_one_time_code')),
          )
          .data!;

      await tester.enterText(
        find.byKey(const Key('sync_recovery_confirmation_input')),
        '$code-wrong',
      );
      await tester.ensureVisible(
        find.byKey(const Key('sync_recovery_confirm_saved')),
      );
      await tester.tap(find.byKey(const Key('sync_recovery_confirm_saved')));
      await tester.pump();
      expect(find.textContaining('does not match'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('sync_recovery_confirmation_input')),
        code,
      );
      await tester.tap(find.byKey(const Key('sync_recovery_confirm_saved')));
      await tester.pump();
      expect(
        find.byKey(const Key('sync_recovery_one_time_code')),
        findsNothing,
      );

      final freshKeyStore = SavedMomentSyncKeyStore(
        InMemorySecureStorageService(),
      );
      var freshIdentity = _authenticatedIdentity('fresh-device');
      final recoveryService = SyncRecoveryService(
        api: api,
        keyStore: freshKeyStore,
        identityProvider: () => freshIdentity,
        adoptRecoveredArchive: (_, archiveId) async {
          freshIdentity = _authenticatedIdentity(archiveId);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SyncRecoveryScreen(
            key: const ValueKey('fresh-device-recovery'),
            service: recoveryService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('sync_recovery_code_input')),
        code,
      );
      await tester.ensureVisible(
        find.byKey(const Key('sync_recovery_restore')),
      );
      await tester.tap(find.byKey(const Key('sync_recovery_restore')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Sync key recovered on this device.'), findsOneWidget);
      expect(await freshKeyStore.readKey('archive-original'), hasLength(32));
      expect(api.transportCalls, 0);
      _expectNoProductionCalls(fixture);
    },
  );

  _coreTestWidgets(
    '12 operational analytics construction and dispatch remain content-free',
    (tester) async {
      ProductAnalytics.resetForTest();
      final dispatched = <({String event, Map<String, Object> parameters})>[];
      ProductAnalytics.installProviderForTest((event, parameters) async {
        dispatched.add((event: event, parameters: parameters));
      });
      await CaptureOperationalAnalytics.originalSaveCompleted(
        OperationalSource.voice,
        OperationalTimingBand.under500ms,
      );
      await TranscriptionOperationalAnalytics.completed(
        OperationalTimingBand.under1s,
      );
      await InterpretationOperationalAnalytics.completed(
        OperationalTimingBand.under2s,
      );
      await RetryOperationalAnalytics.exhausted(
        OperationalAttemptBand.thirdOrMore,
        OperationalFailureCategory.timeout,
      );
      await VaultOperationalAnalytics.writeCompleted(
        OperationalTimingBand.under500ms,
      );
      await SyncRecoveryOperationalAnalytics.recoveryCompleted();
      await ExportOperationalAnalytics.completed(
        OperationalExportFormat.full,
        1000,
      );
      await CommerceOperationalAnalytics.purchaseCompleted();
      await DeletionOperationalAnalytics.completed();

      expect(dispatched, hasLength(9));
      final serialized = jsonEncode([
        for (final event in dispatched)
          {'event': event.event, 'parameters': event.parameters},
      ]);
      for (final privateValue in [
        CoreScenarioFixtures.typedFirst,
        CoreScenarioFixtures.thenQuote,
        CoreScenarioFixtures.privateCorrection,
        'deterministic-observation',
        'entry-private-id',
        '/private/audio/capture.wav',
        'AR1-PRIVATE-RECOVERY-CODE',
      ]) {
        expect(serialized, isNot(contains(privateValue)));
      }
      expect(
        dispatched.map((event) => event.event),
        containsAll([
          'original_save_completed',
          'transcription_completed',
          'interpretation_completed',
          'retry_exhausted',
          'vault_write_completed',
          'recovery_completed',
          'export_completed',
          'purchase_completed',
          'deletion_completed',
        ]),
      );
      _expectNoProductionCalls(fixture);
    },
  );
}

void _coreTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Every scenario boots the production router. Unmount it before the
      // shared services are reset so controllers and global keys cannot leak
      // into the next scenario on a real device.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _startTypedFromRecord(WidgetTester tester) async {
  await _waitFor(tester, const Key('record_idle_type_instead_cta'));
  await tester.tap(find.byKey(const Key('record_idle_type_instead_cta')));
  await _waitFor(tester, const Key('quick_text_capture_field'));
}

Future<void> _finishTypedCapture(
  WidgetTester tester, {
  required String text,
  required bool generateInterpretation,
  bool expectConclusion = false,
}) async {
  await tester.enterText(
    find.byKey(const Key('quick_text_capture_field')),
    text,
  );
  final save = find.byKey(const Key('quick_text_capture_save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  await tester.tap(save);
  final review = find.byKey(const Key('post_transcription_review_dialog'));
  final interpretation = find.byKey(
    const Key('post_capture_interpretation_sheet'),
  );
  await pumpUntil(
    tester,
    () => review.evaluate().isNotEmpty || interpretation.evaluate().isNotEmpty,
    diagnostic: 'typed save did not reach review or interpretation choice',
  );
  if (review.evaluate().isNotEmpty) {
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('post_transcription_review_field')),
          )
          .controller!
          .text,
      text,
    );
    await tester.tap(
      find.byKey(const Key('post_transcription_review_continue')),
    );
  }
  if (generateInterpretation) {
    await _chooseGenerateAndConsent(tester);
    await _waitFor(tester, const Key('post_save_compact_conclusion'));
    return;
  }
  await _waitFor(tester, const Key('post_capture_interpretation_sheet'));
  await _tapVisible(
    tester,
    find.byKey(const Key('post_capture_interpretation_decline')),
  );
  await _waitFor(tester, const Key('focused_auditable_post_save_section'));
  if (expectConclusion) {
    await _waitFor(tester, const Key('post_save_compact_conclusion'));
  }
}

Future<void> _chooseGenerateAndConsent(WidgetTester tester) async {
  await _waitFor(tester, const Key('post_capture_interpretation_sheet'));
  await _tapVisible(
    tester,
    find.byKey(const Key('post_capture_interpretation_generate')),
  );
  await _waitFor(tester, const Key('remote_transcription_disclosure_dialog'));
  expect(find.text('Online interpretation'), findsOneWidget);
  await _tapVisible(
    tester,
    find.byKey(const Key('remote_disclosure_continue')),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

Future<void> _waitFor(WidgetTester tester, Key key) => _waitForFinder(
  tester,
  find.byKey(key),
  diagnostic: 'expected production UI state was not reached',
);

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String diagnostic,
}) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  diagnostic: diagnostic,
);

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  Reflection? reflection,
}) => JournalEntry(
  id: id,
  ownerArchiveId: AppServices.instance.journalStore.ownerArchiveId,
  createdAt: at,
  source: SavedMomentSource.typed,
  transcript: transcript,
  durationSeconds: 12,
  reflection:
      reflection ??
      const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
);

ExplainableConclusion _changeConclusion(
  JournalEntry then,
  JournalEntry now,
) => ExplainableConclusion(
  id: 'weekly-change-conclusion',
  kind: ExplainableInsightKind.change,
  statement: 'Your work message response may have changed.',
  confidence: 75,
  reasoning: const ['The exact saved wording supports this narrow claim.'],
  uncertaintyNote: 'Later saved moments may support or challenge this read.',
  evidence: [
    _citation(then, EvidenceTemporalRole.then),
    _citation(now, EvidenceTemporalRole.now),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The circumstances may explain this wording.',
      rationale: 'More saved moments could support a different explanation.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: now.createdAt.add(const Duration(seconds: 1)),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
);

TranscriptEvidenceCitation _citation(
  JournalEntry entry,
  EvidenceTemporalRole temporalRole,
) => TranscriptEvidenceCitation(
  entryId: entry.id,
  quote: entry.transcript,
  startUtf16: 0,
  endUtf16: entry.transcript.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: entry.createdAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
);

LocalArchiveIdentity _authenticatedIdentity(String archiveId) =>
    LocalArchiveIdentity(
      archiveId: archiveId,
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: 'integration-account',
      ownershipState: LocalArchiveOwnershipState.active,
    );

final class _DeterministicRecoveryApi extends JournalSyncApiClient {
  factory _DeterministicRecoveryApi() {
    final networkCalls = <int>[0];
    return _DeterministicRecoveryApi._(
      networkCalls,
      ApiTransport(
        baseUrl: 'https://integration.invalid',
        httpClient: MockClient((_) async {
          networkCalls[0] += 1;
          return http.Response('{"error":"network disabled"}', 503);
        }),
      ),
    );
  }

  _DeterministicRecoveryApi._(this._networkCalls, ApiTransport transport)
    : super(transport);

  Map<String, dynamic>? envelope;
  final List<int> _networkCalls;

  int get transportCalls => _networkCalls.single;

  @override
  Future<Map<String, dynamic>> syncRecoveryStatus() async => {
    'enabled': envelope != null,
    if (envelope case final value?) ...{
      'envelopeRevision': value['envelopeRevision'],
      'updatedAt': value['updatedAt'],
    },
  };

  @override
  Future<Map<String, dynamic>> syncRecoveryFetch() async => {
    'envelope': envelope,
  };

  @override
  Future<Map<String, dynamic>> syncRecoveryUpsert(
    Map<String, dynamic> value,
  ) async {
    envelope = Map<String, dynamic>.from(value);
    return {'ok': true};
  }

  @override
  Future<void> syncRecoveryDelete() async {
    envelope = null;
  }
}

void _expectNoProductionCalls(DeterministicCoreTestBootstrap fixture) {
  expect(fixture.blockedTransportCalls, 0);
  expect(fixture.revenueCatProvider.initializeCalls, 0);
}

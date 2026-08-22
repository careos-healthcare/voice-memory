import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/low_evidence/low_evidence_copy.dart';
import 'package:archiveme_mobile/features/low_evidence/low_evidence_engine.dart';
import 'package:archiveme_mobile/features/low_evidence/low_evidence_model.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/patterns_evidence_quality_fallback_view.dart';
import 'package:archiveme_mobile/widgets/record/low_evidence_guidance_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  String? transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript:
        transcript ??
        'A long enough transcript to count as a saved reflection for tests.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

late TestStorageSandbox _sandbox;

Future<void> _resetServices() async {
  await AppServices.resetForTest(
    journalPath: _sandbox.journalPath,
    prefsPath: _sandbox.prefsPath,
    skipRevenueCat: true,
  );
}

Future<void> _pumpRecordReady(
  WidgetTester tester, {
  List<JournalEntry>? entries,
}) async {
  if (entries != null) {
    await tester.runAsync(() async {
      for (final entry in entries) {
        await AppServices.instance.journalStore.save(entry);
      }
    });
  }
  await tester.binding.setSurfaceSize(const Size(390, 2800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(withAppProviderScope(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RecordScreen(
          suggestionAttributionStore: MemorySuggestionAttributionStore(),
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
        ),
      ),
    )));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    _sandbox = TestStorageSandbox.create();
    await _resetServices();
  });

  tearDown(() => _sandbox.dispose());
  group('LowEvidenceEngine', () {
    test('zero entries returns null', () {
      expect(LowEvidenceEngine.buildForRecordReady(entries: const []), isNull);
      expect(LowEvidenceEngine.buildForPatternsTab(entries: const []), isNull);
    });

    test('one real entry shows archive started copy', () {
      final guidance = LowEvidenceEngine.buildForRecordReady(
        entries: [_entry(id: 'a')],
      );

      expect(guidance, isNotNull);
      expect(guidance!.kind, LowEvidenceStateKind.oneRealEntry);
      expect(guidance.title, LowEvidenceCopy.oneEntryTitle);
      expect(guidance.body, LowEvidenceCopy.oneEntryBody);
      expect(guidance.claimsRepeatForming, isFalse);
    });

    test('two unrelated real entries show nothing clear yet copy', () {
      final guidance = LowEvidenceEngine.buildForRecordReady(
        entries: [
          _entry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _entry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        ],
      );

      expect(guidance, isNotNull);
      expect(guidance!.kind, LowEvidenceStateKind.twoUnrelatedRealEntries);
      expect(guidance.title, LowEvidenceCopy.twoUnrelatedTitle);
      expect(guidance.body, LowEvidenceCopy.twoUnrelatedBody);
      expect(guidance.claimsRepeatForming, isFalse);
    });

    test('two related entries show one more related moment copy', () {
      final guidance = LowEvidenceEngine.buildForRecordReady(
        entries: [
          _entry(
            id: 'a',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: 'b',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );

      expect(guidance, isNotNull);
      expect(guidance!.kind, LowEvidenceStateKind.twoRelatedNotEnough);
      expect(guidance.title, LowEvidenceCopy.twoRelatedTitle);
      expect(guidance.body, LowEvidenceCopy.twoRelatedBody);
      expect(guidance.claimsRepeatForming, isTrue);
    });

    test('generic test-only shows patterns still forming', () {
      final guidance = LowEvidenceEngine.buildForPatternsTab(
        entries: [_entry(id: 'a', transcript: 'mic test')],
      );

      expect(guidance, isNotNull);
      expect(guidance!.kind, LowEvidenceStateKind.genericTestOnly);
      expect(guidance.title, LowEvidenceCopy.genericTestTitle);
      expect(guidance.body, LowEvidenceCopy.genericTestBody);
    });

    test('quiet-day only shows quiet days count', () {
      final guidance = LowEvidenceEngine.buildForPatternsTab(
        entries: [
          _entry(
            id: 'a',
            transcript: RecordCaptureModeCopy.quietDayDefaultSaveText,
          ),
        ],
      );

      expect(guidance, isNotNull);
      expect(guidance!.kind, LowEvidenceStateKind.quietDayOnly);
      expect(guidance.title, LowEvidenceCopy.quietDayTitle);
      expect(guidance.body, LowEvidenceCopy.quietDayBody);
      expect(
        RecordCaptureModeEngine.isQuietDayText(
          RecordCaptureModeCopy.quietDayDefaultSaveText,
        ),
        isTrue,
      );
    });

    test('first proof path returns null guidance', () {
      final entries = List.generate(
        3,
        (i) => _entry(
          id: 'repeat_$i',
          createdAt: DateTime(2026, 6, 10 + i, 12),
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
      );

      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(LowEvidenceEngine.buildForRecordReady(entries: entries), isNull);
    });

    test('copy does not expose internal quality labels', () {
      for (final text in LowEvidenceCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('weak')));
        expect(text.toLowerCase(), isNot(contains('unusable')));
      }
    });
  });

  group('Post-save no repeat copy', () {
    test('uses non-failure reassurance', () {
      expect(
        PostSaveRecordedSummaryCopy.noPatternReassurance,
        LowEvidenceCopy.postSaveNoRepeat,
      );
      expect(
        PostSaveRecordedSummaryCopy.noPatternReassurance,
        contains('does not need every entry'),
      );
      expect(
        PostSaveRecordedSummaryCopy.noPatternReassurance.toLowerCase(),
        isNot(contains('failed')),
      );
    });
  });

  group('LowEvidenceGuidanceCard', () {
    testWidgets('renders title and body', (tester) async {
      const guidance = LowEvidenceGuidance(
        kind: LowEvidenceStateKind.oneRealEntry,
        title: LowEvidenceCopy.oneEntryTitle,
        body: LowEvidenceCopy.oneEntryBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LowEvidenceGuidanceCard(guidance: guidance)),
        ),
      );

      expect(
        find.byKey(const Key('low_evidence_guidance_card_oneRealEntry')),
        findsOneWidget,
      );
      expect(find.text(LowEvidenceCopy.oneEntryTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.oneEntryBody), findsOneWidget);
    });
  });

  group('PatternsEvidenceQualityFallbackView', () {
    testWidgets('generic test fallback uses low-evidence copy', (tester) async {
      const guidance = LowEvidenceGuidance(
        kind: LowEvidenceStateKind.genericTestOnly,
        title: LowEvidenceCopy.genericTestTitle,
        body: LowEvidenceCopy.genericTestBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEvidenceQualityFallbackView(
              genericTestOnly: true,
              lowEvidence: guidance,
            ),
          ),
        ),
      );

      expect(find.text(LowEvidenceCopy.genericTestTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.genericTestBody), findsOneWidget);
    });

    testWidgets('quiet-day fallback uses quiet-day copy', (tester) async {
      const guidance = LowEvidenceGuidance(
        kind: LowEvidenceStateKind.quietDayOnly,
        title: LowEvidenceCopy.quietDayTitle,
        body: LowEvidenceCopy.quietDayBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEvidenceQualityFallbackView(lowEvidence: guidance),
          ),
        ),
      );

      expect(find.text(LowEvidenceCopy.quietDayTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.quietDayBody), findsOneWidget);
    });
  });

  group('Record ready surface', () {
    testWidgets('zero entries do not show low-evidence card', (tester) async {
      await _pumpRecordReady(tester);

      expect(find.byType(LowEvidenceGuidanceCard), findsNothing);
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    });

    testWidgets('one entry ready shows archive started card and mic CTA', (
      tester,
    ) async {
      await _pumpRecordReady(tester, entries: [_entry(id: 'a')]);

      expect(
        find.byKey(const Key('low_evidence_guidance_card_oneRealEntry')),
        findsOneWidget,
      );
      expect(find.text(LowEvidenceCopy.oneEntryTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.oneEntryBody), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('two unrelated entries do not claim repeat forming', (
      tester,
    ) async {
      await _pumpRecordReady(
        tester,
        entries: [
          _entry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _entry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        ],
      );

      expect(
        find.byKey(
          const Key('low_evidence_guidance_card_twoUnrelatedRealEntries'),
        ),
        findsOneWidget,
      );
      expect(find.text(LowEvidenceCopy.twoUnrelatedTitle), findsOneWidget);
      expect(find.text(LowEvidenceCopy.twoRelatedTitle), findsNothing);
      expect(find.textContaining('thread comes back'), findsNothing);
    });

    testWidgets('two related entries show related-not-enough copy', (
      tester,
    ) async {
      await _pumpRecordReady(
        tester,
        entries: [
          _entry(
            id: 'a',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: 'b',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );

      expect(
        find.byKey(const Key('low_evidence_guidance_card_twoRelatedNotEnough')),
        findsOneWidget,
      );
      expect(find.text(LowEvidenceCopy.twoRelatedTitle), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsOneWidget);
    });

    testWidgets('three confirmed-repeat entries hide low-evidence card', (
      tester,
    ) async {
      final entries = List.generate(
        3,
        (i) => _entry(
          id: 'repeat_$i',
          createdAt: DateTime(2026, 6, 10 + i, 12),
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
      );
      await _pumpRecordReady(tester, entries: entries);

      expect(find.byType(LowEvidenceGuidanceCard), findsNothing);
    });
  });

  group('Post-save surface', () {
    testWidgets('no-repeat post-save uses reassurance copy', (tester) async {
      final entries = [
        _entry(
          id: 'a',
          transcript: 'A quiet moment about lunch with a friend today.',
        ),
        _entry(
          id: 'b',
          transcript: 'Another unrelated note about errands this afternoon.',
        ),
      ];
      await tester.runAsync(() async {
        for (final entry in entries) {
          await AppServices.instance.journalStore.save(entry);
        }
      });
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entries,
        ),
      );
      addTearDown(() => VisualAuditOverrides.setRecordPresentation(null));

      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text(PostSaveRecordedSummaryCopy.noPatternReassurance),
        findsOneWidget,
      );
      expect(find.byType(PostSaveRecordedSummaryCard), findsOneWidget);
    });
  });
}
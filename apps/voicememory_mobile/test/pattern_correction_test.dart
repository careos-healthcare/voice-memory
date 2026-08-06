import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/archive_controls/archive_control_copy.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_action_loop/first_proof_action_loop_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:voicememory_mobile/features/pattern_correction/pattern_correction_analytics.dart';
import 'package:voicememory_mobile/features/pattern_correction/pattern_correction_copy.dart';
import 'package:voicememory_mobile/features/pattern_correction/pattern_correction_engine.dart';
import 'package:voicememory_mobile/features/pattern_correction/pattern_correction_gates.dart';
import 'package:voicememory_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:voicememory_mobile/features/pattern_naming/pattern_name_copy.dart';
import 'package:voicememory_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_correction_sheet.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_action_loop_card.dart';
import 'support/test_storage_sandbox.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

PatternDetailResult _detailFor(List<JournalEntry> entries) {
  final signal = EarlyFirstSignalEngine.build(entries: entries);
  return PatternDetailEngine.build(
    entries: entries,
    confirmedRepeat: signal,
    viewingConfirmedRepeatOrTimeline: true,
  )!;
}

PatternCorrectionContext _contextForDetail(List<JournalEntry> entries) {
  final detail = _detailFor(entries);
  return PatternCorrectionGates.buildForPatternDetail(
    detail: detail,
    entryCount: entries.length,
    entries: entries,
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  PatternCorrectionContext contextData,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                PatternCorrectionSheet.show(context, contextData: contextData),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _selectReason(
  WidgetTester tester,
  PatternCorrectionReason reason,
) async {
  await tester.tap(
    find.byKey(
      Key(
        'pattern_correction_reason_${PatternCorrectionAnalytics.reasonKey(reason)}',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    PatternCorrectionAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });


  tearDown(() => sandbox.dispose());
  group('PatternCorrectionEngine', () {
    test('maps each reason to the specified actions', () {
      expect(
        PatternCorrectionEngine.actionsFor(
          PatternCorrectionReason.wrongPattern,
        ),
        [
          PatternCorrectionAction.renamePattern,
          PatternCorrectionAction.removeFromPattern,
          PatternCorrectionAction.betaFeedback,
        ],
      );
      expect(
        PatternCorrectionEngine.actionsFor(
          PatternCorrectionReason.wrongWording,
        ),
        [
          PatternCorrectionAction.renamePattern,
          PatternCorrectionAction.correctTranscript,
        ],
      );
      expect(
        PatternCorrectionEngine.actionsFor(PatternCorrectionReason.tooPersonal),
        [
          PatternCorrectionAction.deleteMoment,
          PatternCorrectionAction.removeFromPattern,
          PatternCorrectionAction.privacyCentre,
        ],
      );
      expect(
        PatternCorrectionEngine.actionsFor(
          PatternCorrectionReason.doesNotBelong,
        ),
        [
          PatternCorrectionAction.removeFromPattern,
          PatternCorrectionAction.deleteMoment,
        ],
      );
      expect(
        PatternCorrectionEngine.actionsFor(PatternCorrectionReason.notUseful),
        [
          PatternCorrectionAction.betaFeedback,
          PatternCorrectionAction.keepRecording,
        ],
      );
    });
  });

  group('PatternCorrectionGates', () {
    test('shows for grounded first proof entries', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;
      expect(PatternCorrectionGates.shouldShowForEntries(entries), isTrue);
      expect(
        PatternCorrectionGates.shouldShowForFirstProofNo(
          entries: entries,
          payoff: payoff,
        ),
        isTrue,
      );
    });

    test('hidden for generic quiet pending and degraded entries', () {
      final generic = [
        _entry(id: 'g1', transcript: 'This is a test to check function'),
        _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        _entry(id: 'g3', transcript: 'This is a third test for pressure'),
      ];
      final quiet = [
        _entry(id: 'q1', transcript: 'Nothing much today.'),
        _entry(id: 'q2', transcript: 'Nothing much today.'),
        _entry(id: 'q3', transcript: 'Nothing much today.'),
      ];
      final pending = [
        _entry(id: 'v1', transcript: _placeholder),
        _entry(id: 'v2', transcript: _placeholder),
        _entry(id: 'v3', transcript: _placeholder),
      ];

      for (final entries in [generic, quiet, pending]) {
        expect(PatternCorrectionGates.shouldShowForEntries(entries), isFalse);
      }
    });
  });

  group('PatternCorrectionAnalytics', () {
    test('events contain metadata only', () {
      final events = <String, Map<String, Object>>{};
      PatternCorrectionAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      PatternCorrectionAnalytics.opened(
        source: 'pattern_detail',
        entryCount: 3,
      );
      PatternCorrectionAnalytics.reasonSelected(
        source: 'pattern_detail',
        entryCount: 3,
        reason: PatternCorrectionReason.wrongPattern,
      );
      PatternCorrectionAnalytics.actionSelected(
        source: 'pattern_detail',
        entryCount: 3,
        action: PatternCorrectionAction.renamePattern,
      );

      expect(
        events.keys,
        containsAll([
          PatternCorrectionAnalytics.openedEvent,
          PatternCorrectionAnalytics.reasonSelectedEvent,
          PatternCorrectionAnalytics.actionSelectedEvent,
        ]),
      );
      expect(
        events[PatternCorrectionAnalytics.openedEvent]!.keys,
        containsAll(['source', 'entry_count']),
      );
      expect(
        events[PatternCorrectionAnalytics.reasonSelectedEvent]!.keys,
        containsAll(['source', 'entry_count', 'reason_type']),
      );
      expect(
        events[PatternCorrectionAnalytics.actionSelectedEvent]!.keys,
        containsAll(['source', 'entry_count', 'action_type']),
      );

      final flat = events.values
          .expand((props) => props.values)
          .map((value) => value.toString().toLowerCase())
          .join(' ');
      expect(flat, isNot(contains('said yes')));
      expect(flat, isNot(contains('transcript')));
    });
  });

  group('PatternCorrectionSheet', () {
    testWidgets('shows reasons then actions for wrong pattern', (tester) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));

      expect(find.byKey(const Key('pattern_correction_sheet')), findsOneWidget);
      expect(find.text(PatternCorrectionCopy.sheetTitle), findsOneWidget);
      expect(
        find.text(PatternCorrectionCopy.wrongPatternReason),
        findsOneWidget,
      );

      await _selectReason(tester, PatternCorrectionReason.wrongPattern);

      expect(
        find.text(PatternCorrectionCopy.renamePatternAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.removeFromPatternAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.betaFeedbackAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.correctTranscriptAction),
        findsNothing,
      );
    });

    testWidgets('wrong wording shows rename and correct transcript', (
      tester,
    ) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.wrongWording);

      expect(
        find.text(PatternCorrectionCopy.renamePatternAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.correctTranscriptAction),
        findsOneWidget,
      );
    });

    testWidgets('too personal shows delete remove and privacy centre', (
      tester,
    ) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.tooPersonal);

      expect(
        find.text(PatternCorrectionCopy.deleteMomentAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.removeFromPatternAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.privacyCentreAction),
        findsOneWidget,
      );
    });

    testWidgets('does not belong shows remove and delete', (tester) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.doesNotBelong);

      expect(
        find.text(PatternCorrectionCopy.removeFromPatternAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.deleteMomentAction),
        findsOneWidget,
      );
    });

    testWidgets('not useful shows beta feedback and keep recording', (
      tester,
    ) async {
      final contextData = PatternCorrectionGates.buildForFirstProofNo(
        entries: _threeRelatedEntries(),
        payoff: FirstProofPayoffEngine.build(entries: _threeRelatedEntries())!,
        onKeepRecording: () {},
      );
      await _openSheet(tester, contextData);
      await _selectReason(tester, PatternCorrectionReason.notUseful);

      expect(
        find.text(PatternCorrectionCopy.betaFeedbackAction),
        findsOneWidget,
      );
      expect(
        find.text(PatternCorrectionCopy.keepRecordingAction),
        findsOneWidget,
      );
    });

    testWidgets('rename action opens existing rename sheet', (tester) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.wrongPattern);
      await tester.tap(
        find.byKey(const Key('pattern_correction_action_rename_pattern')),
      );
      await tester.pumpAndSettle();

      expect(find.text(PatternNameCopy.renameSheetTitle), findsOneWidget);
      expect(find.byKey(const Key('rename_pattern_field')), findsOneWidget);
    });

    testWidgets('beta feedback action opens existing beta sheet', (
      tester,
    ) async {
      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.wrongPattern);
      await tester.tap(
        find.byKey(const Key('pattern_correction_action_beta_feedback')),
      );
      await tester.pumpAndSettle();

      expect(find.text(BetaFeedbackCopy.sheetTitle), findsOneWidget);
    });

    testWidgets('privacy centre action routes to trust centre', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => PatternCorrectionSheet.show(
                    context,
                    contextData: _contextForDetail(_threeRelatedEntries()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('PRIVACY CENTRE'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _selectReason(tester, PatternCorrectionReason.tooPersonal);
      await tester.tap(
        find.byKey(const Key('pattern_correction_action_privacy_centre')),
      );
      await tester.pumpAndSettle();

      expect(find.text('PRIVACY CENTRE'), findsOneWidget);
    });

    testWidgets('delete action requires confirmation not auto-delete', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final entry in _threeRelatedEntries()) {
          await AppServices.instance.journalStore.save(entry);
        }
      });

      await _openSheet(tester, _contextForDetail(_threeRelatedEntries()));
      await _selectReason(tester, PatternCorrectionReason.tooPersonal);
      await tester.tap(
        find.byKey(const Key('pattern_correction_action_delete_moment')),
      );
      await tester.pumpAndSettle();

      expect(find.text(ArchiveControlCopy.deleteDialogTitle), findsOneWidget);
      expect(find.text(ArchiveControlCopy.deleteDialogConfirm), findsOneWidget);
      expect(await AppServices.instance.journalStore.loadAll(), hasLength(3));
    });
  });

  group('surface integration', () {
    testWidgets('control appears in pattern detail sheet', (tester) async {
      final entries = _threeRelatedEntries();
      final detail = _detailFor(entries);
      final buildInput = PatternDetailBuildInput(
        entries: entries,
        confirmedRepeat: EarlyFirstSignalEngine.build(entries: entries),
        viewingConfirmedRepeatOrTimeline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatternDetailSheet(
                detail: detail,
                buildInput: buildInput,
                entryCount: entries.length,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_correction_control')),
        findsOneWidget,
      );
      expect(find.text(PatternCorrectionCopy.controlLabel), findsOneWidget);
    });

    testWidgets('control appears after first proof No answer', (tester) async {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries)!;
      final content = FirstProofActionLoopEngine.build(
        answer: FirstProofTruthAnswer.no,
        entries: entries,
        payoff: payoff,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstProofActionLoopCard(
              content: content,
              entryCount: 3,
              onWatchThisNext: () {},
              onKeepRecording: () {},
              onOpenPatternCorrection: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(content.canShowPatternCorrection, isTrue);
      expect(
        find.byKey(const Key('pattern_correction_control')),
        findsOneWidget,
      );
    });

    testWidgets('hidden in pattern detail without grounded entries', (
      tester,
    ) async {
      final generic = [
        _entry(id: 'g1', transcript: 'This is a test to check function'),
        _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        _entry(id: 'g3', transcript: 'This is a third test for pressure'),
      ];
      final detail = PatternDetailEngine.build(
        entries: generic,
        viewingConfirmedRepeatOrTimeline: true,
      );
      if (detail == null) {
        expect(
          find.byKey(const Key('pattern_correction_control')),
          findsNothing,
        );
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternDetailSheet(
              detail: detail,
              buildInput: PatternDetailBuildInput(
                entries: generic,
                viewingConfirmedRepeatOrTimeline: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pattern_correction_control')), findsNothing);
    });
  });

  group('protected areas untouched', () {
    test('RevenueCat product id unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('feature files avoid billing entitlement and signing', () {
      const paths = [
        'lib/features/pattern_correction/pattern_correction_copy.dart',
        'lib/features/pattern_correction/pattern_correction_model.dart',
        'lib/features/pattern_correction/pattern_correction_analytics.dart',
        'lib/features/pattern_correction/pattern_correction_engine.dart',
        'lib/features/pattern_correction/pattern_correction_gates.dart',
        'lib/widgets/patterns/pattern_correction_sheet.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('purchasepackage')));
        expect(content, isNot(contains('proentitlementid')));
        expect(content, isNot(contains('build_number')));
        expect(content, isNot(contains('productidentifier')));
      }
    });

    test('copy reuses existing archive control labels', () {
      expect(
        PatternCorrectionCopy.deleteMomentAction,
        ArchiveControlCopy.deleteMomentButton,
      );
      expect(
        PatternCorrectionCopy.removeFromPatternAction,
        ArchiveControlCopy.excludeFromPatternButton,
      );
      expect(
        PatternCorrectionCopy.correctTranscriptAction,
        TranscriptCorrectionCopy.actionLabel,
      );
      expect(PatternCorrectionCopy.privacyCentreAction, PrivacyTrustCopy.title);
    });
  });
}

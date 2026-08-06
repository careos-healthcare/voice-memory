
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/activation/second_session_payoff.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:voicememory_mobile/widgets/record/second_session_payoff_card.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

const _bannedOneEntryWords = [
  'loop',
  'repeat',
  'repeating',
  'pattern found',
  'pressure loop',
];

const _bannedPatternClaims = [
  'pattern found',
  'found a pattern',
  'pressure loop',
  'working hypothesis',
  'is a pattern',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedCopy(Iterable<String> visible, List<String> banned) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in banned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {

  group('SecondSessionPayoffEngine', () {
    test('returns null unless exactly two eligible entries', () {
      expect(
        SecondSessionPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
          ],
        ),
        isNull,
      );
      expect(
        SecondSessionPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript: 'My sister called about planning the weekend trip.',
            ),
            _voiceEntry(
              id: 'e3',
              transcript: 'I kept checking messages after I wanted to stop.',
            ),
          ],
        ),
        isNull,
      );
    });

    test('ungrounded two entries uses cautious comparison copy', () {
      final payoff = SecondSessionPayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: 'A quiet moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Another unrelated note about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, VisibleArchiveProofCopy.twoEntryCompareTitle);
      expect(payoff.body, VisibleArchiveProofCopy.twoEntryBodyUngrounded);
      expect(payoff.body, contains('No clear repeat yet'));
      expect(payoff.hasGroundedMatch, isFalse);
      _expectNoBannedCopy([payoff.title, payoff.body], _bannedPatternClaims);
    });

    test('grounded two entries says may be related not pattern found', () {
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isTrue,
      );

      final payoff = SecondSessionPayoffEngine.build(entries: entries);
      expect(payoff, isNotNull);
      expect(payoff!.body, VisibleArchiveProofCopy.twoEntryBodyGrounded);
      expect(payoff.body, contains('may be related'));
      expect(payoff.hasGroundedMatch, isTrue);
      _expectNoBannedCopy([payoff.title, payoff.body], _bannedPatternClaims);
    });

    test(
      'analysis failure adds deferred footnote without claiming insight',
      () {
        final payoff = SecondSessionPayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'A quiet moment about lunch with a friend today.',
              createdAt: DateTime(2026, 6, 11, 12),
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Another unrelated note about errands this afternoon.',
              createdAt: DateTime(2026, 6, 12, 12),
            ),
          ],
          analysisSucceeded: false,
        );

        expect(payoff!.footnoteLine, isNotNull);
        expect(payoff.footnoteLine, contains('This moment is saved'));
      },
    );
  });

  group('SecondSessionPayoffCard', () {
    testWidgets('shows comparison title, CTAs, and ungrounded body', (
      tester,
    ) async {
      const payoff = SecondSessionPayoff(
        title: SecondSessionPayoffCopy.title,
        body: SecondSessionPayoffCopy.bodyUngrounded,
        primaryCta: SecondSessionPayoffCopy.primaryCta,
        secondaryCta: SecondSessionPayoffCopy.secondaryCta,
        hasGroundedMatch: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SecondSessionPayoffCard(
              payoff: payoff,
              onAddAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('second_session_payoff_card')),
        findsOneWidget,
      );
      expect(
        find.text('ArchiveMe has two moments to compare.'),
        findsOneWidget,
      );
      expect(find.textContaining('No clear repeat yet'), findsOneWidget);
      expect(find.text('Record if it happens again'), findsOneWidget);
      expect(find.text('View archive'), findsOneWidget);
      expect(find.textContaining('pattern found'), findsNothing);
    });
  });

  group('RecordScreen second session payoff', () {

  late TestStorageSandbox sandbox;


    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
    });

    tearDown(() => sandbox.dispose());

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpTwoEntryDone(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool lastCaptureAnalysisSucceeded = true,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
      'two entries post-save stays focused without duplicate payoff cards',
      (tester) async {
        await pumpTwoEntryDone(
          tester,
          entriesAfterSave: [
            _voiceEntry(
              id: 'e1',
              transcript: 'A quiet moment about lunch with a friend today.',
              createdAt: DateTime(2026, 6, 11, 12),
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Another unrelated note about errands this afternoon.',
              createdAt: DateTime(2026, 6, 12, 12),
            ),
          ],
        );

        expect(
          find.byKey(const Key('post_save_archive_home_nudge_card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('second_session_payoff_card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('post_save_focused_actions_bar')),
          findsOneWidget,
        );
        expect(find.text(PostSaveRecordedSummaryCopy.title), findsOneWidget);
        expect(
          find.byKey(const Key('post_save_add_one_more_moment_cta')),
          findsOneWidget,
        );
        expect(
          find.text(PostSaveFocusedActionsCopy.viewPatterns),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('analysis_fallback_payoff_card')),
          findsNothing,
        );
      },
    );

    testWidgets('grounded two entries keep one primary result on record screen', (
      tester,
    ) async {
      await pumpTwoEntryDone(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I said yes again even though I was already tired from work today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'I took responsibility again before asking anyone for help today.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      expect(
        find.byKey(const Key('post_save_archive_home_nudge_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('second_session_payoff_card')), findsNothing);
      expect(
        find.byKey(const Key('post_save_focused_actions_bar')),
        findsOneWidget,
      );
      expect(find.textContaining('pattern found'), findsNothing);
    });

    testWidgets('one entry UI avoids forbidden loop and repeat language', (
      tester,
    ) async {
      await pumpTwoEntryDone(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      _expectNoBannedCopy(_visibleText(tester), _bannedOneEntryWords);
      expect(find.byKey(const Key('second_session_payoff_card')), findsNothing);
    });
  });
}

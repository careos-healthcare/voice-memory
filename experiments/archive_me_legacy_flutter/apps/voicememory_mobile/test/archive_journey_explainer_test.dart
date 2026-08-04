import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/onboarding/archive_journey_copy.dart';
import 'package:voicememory_mobile/features/onboarding/archive_journey_explainer_gates.dart';
import 'package:voicememory_mobile/features/onboarding/archive_journey_model.dart';
import 'package:voicememory_mobile/features/onboarding/first_proof_journey_copy.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/onboarding/archive_journey_explainer_card.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/record/record_first_use_capture_section.dart';

JournalEntry _entry({
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

List<JournalEntry> _threeRelatedRepeatEntries() => [
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

void main() {
  group('ArchiveJourneyExplainerGates', () {
    test('compact appears before first proof at entry zero', () {
      expect(
        ArchiveJourneyExplainerGates.showCompactOnRecord(
          loaded: true,
          entryCount: 0,
          isPostSave: false,
          entries: const [],
        ),
        isTrue,
      );
    });

    test('compact hidden after first proof', () {
      final entries = _threeRelatedRepeatEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
      expect(
        ArchiveJourneyExplainerGates.showCompactOnRecord(
          loaded: true,
          entryCount: 0,
          isPostSave: false,
          entries: entries,
        ),
        isFalse,
      );
      expect(
        ArchiveJourneyExplainerGates.showCompactOnRecord(
          loaded: true,
          entryCount: 3,
          isPostSave: false,
          entries: entries,
        ),
        isFalse,
      );
    });

    test('journey strip appears at two entries before first proof', () {
      expect(
        ArchiveJourneyExplainerGates.showFirstProofJourneyStripOnRecord(
          loaded: true,
          entryCount: 2,
          isPostSave: false,
          entries: const [],
        ),
        isTrue,
      );
    });

    test('journey strip hidden after four entries', () {
      expect(
        ArchiveJourneyExplainerGates.showFirstProofJourneyStripOnRecord(
          loaded: true,
          entryCount: 4,
          isPostSave: false,
          entries: const [],
        ),
        isFalse,
      );
    });

    test('compact hidden on post-save', () {
      expect(
        ArchiveJourneyExplainerGates.showCompactOnRecord(
          loaded: true,
          entryCount: 0,
          isPostSave: true,
          entries: const [],
        ),
        isFalse,
      );
    });

    test('full explainer allowed on patterns empty before first proof', () {
      expect(
        ArchiveJourneyExplainerGates.showFullOnPatternsEmpty(
          hasFirstProof: false,
        ),
        isTrue,
      );
      expect(
        ArchiveJourneyExplainerGates.showFullOnPatternsEmpty(
          hasFirstProof: true,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveJourneyExplainer model', () {
    test('full journey steps render in exact order', () {
      final explainer = ArchiveJourneyExplainer.full();
      expect(explainer.steps.map((step) => step.title).toList(), [
        ArchiveJourneyCopy.step1Title,
        ArchiveJourneyCopy.step2Title,
        ArchiveJourneyCopy.step3Title,
        ArchiveJourneyCopy.step4Title,
        ArchiveJourneyCopy.step5Title,
      ]);
    });

    test('compact journey shows three short step labels only', () {
      final explainer = ArchiveJourneyExplainer.compact();
      expect(explainer.steps, hasLength(3));
      expect(explainer.steps.map((step) => step.title).toList(), [
        ArchiveJourneyCopy.compactStep1Title,
        ArchiveJourneyCopy.compactStep2Title,
        ArchiveJourneyCopy.compactStep3Title,
      ]);
    });

    test('pro step mentions longer proof trail continuity', () {
      expect(ArchiveJourneyCopy.step5Body, contains('longer proof trail'));
      expect(ArchiveJourneyCopy.step5Title, 'Keep the longer proof trail');
    });

    test('no advice coaching or therapy language in copy', () {
      for (final line in ArchiveJourneyExplainer.full().visibleCopyBlocks) {
        for (final violation in ProofSurfaceAdviceGuard.violationsIn(line)) {
          fail('"$line" contains banned phrase "$violation"');
        }
        expect(line.toLowerCase(), isNot(contains('therapy')));
        expect(line.toLowerCase(), isNot(contains('diagnosis')));
      }
    });

    test('visible copy avoids transcript phrase and user entry text', () {
      final joined = ArchiveJourneyExplainer.full().visibleCopyBlocks
          .join('\n')
          .toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes')));
    });
  });

  group('ArchiveJourneyExplainerCard', () {
    testWidgets('compact card renders without buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveJourneyExplainerCard(
              explainer: ArchiveJourneyExplainer.compact(),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_journey_explainer_card_compact')),
        findsOneWidget,
      );
      expect(find.text(ArchiveJourneyCopy.title), findsOneWidget);
      expect(
        find.text('1. ${ArchiveJourneyCopy.compactStep1Title}'),
        findsOneWidget,
      );
      expect(
        find.text('2. ${ArchiveJourneyCopy.compactStep2Title}'),
        findsOneWidget,
      );
      expect(
        find.text('3. ${ArchiveJourneyCopy.compactStep3Title}'),
        findsOneWidget,
      );
      expect(find.text(ArchiveJourneyCopy.compactHelper), findsOneWidget);
      expect(find.text(ArchiveJourneyCopy.step5Title), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('full card renders all five steps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveJourneyExplainerCard(
                explainer: ArchiveJourneyExplainer.full(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_journey_explainer_card_full')),
        findsOneWidget,
      );
      expect(find.text(ArchiveJourneyCopy.step5Title), findsOneWidget);
      expect(find.text(ArchiveJourneyCopy.step5Body), findsOneWidget);
    });
  });

  group('Record first-use integration', () {
    testWidgets('journey strip appears inside first-use capture section', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordFirstUseCaptureSection(
                onRecord: () {},
                recordButtonLabel: VisibleArchiveProofCopy.firstUseCaptureCta,
                showFirstProofJourneyStrip: true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('first_proof_journey_strip_card')),
        findsOneWidget,
      );
      expect(find.text(FirstProofJourneyCopy.strip), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.firstUseCaptureCta),
        findsOneWidget,
      );
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    });

    testWidgets('first-use section hides journey when flag is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordFirstUseCaptureSection(
              onRecord: () {},
              recordButtonLabel: VisibleArchiveProofCopy.firstUseCaptureCta,
              showFirstProofJourneyStrip: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('first_proof_journey_strip_card')),
        findsNothing,
      );
    });
  });

  group('Patterns empty state', () {
    testWidgets('shows full journey explainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEmptyView(
              fillViewport: false,
              showArchiveJourneyExplainer: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_journey_explainer_card_full')),
        findsOneWidget,
      );
      expect(find.text(ArchiveJourneyCopy.step4Title), findsOneWidget);
      expect(find.text(ArchiveJourneyCopy.step5Body), findsOneWidget);
    });
  });

  group('Product intuition empty state copy', () {
    const bannedPhrases = [
      'no data',
      'nothing here',
      'start journaling',
      'ask ai',
      'complete your entry',
    ];

    final emptyStateCopy = [
      RecordScreenFramingCopy.emptyArchiveTitle,
      RecordScreenFramingCopy.emptyArchiveBody,
      RecordFirstUsePromptCopy.body,
      VisibleArchiveProofCopy.patternsMindMapEmptyTitle,
      VisibleArchiveProofCopy.patternsMindMapEmptyBody,
      ConsumerUiCopy.patternsEmptyPageTitle,
      ConsumerUiCopy.patternsEarlyStateBody,
      EmptyArchiveCopy.firstRecordingTitle,
      ConsumerUiCopy.progressEmptyTitle,
      ConsumerUiCopy.progressEmptyBody,
    ];

    test('empty states avoid dead generic copy', () {
      for (final line in emptyStateCopy) {
        final lower = line.toLowerCase();
        for (final banned in bannedPhrases) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: '$line contains $banned',
          );
        }
        expect(lower, isNot(contains('chat')));
        expect(lower, isNot(equals('empty')));
      }
    });

    test('empty states use guided evidence-first language', () {
      expect(
        RecordScreenFramingCopy.emptyArchiveTitle,
        'Save one real moment.',
      );
      expect(
        VisibleArchiveProofCopy.patternsMindMapEmptyBody,
        contains('what repeats'),
      );
      expect(
        RecordFirstUsePromptCopy.footer,
        contains('Ten seconds is enough'),
      );
    });
    test(
      'compact helper avoids duplicating ten seconds from first-use footer',
      () {
        expect(
          ArchiveJourneyCopy.compactHelper.toLowerCase(),
          isNot(contains('ten seconds')),
        );
        expect(
          RecordFirstUsePromptCopy.footer,
          contains('Ten seconds is enough'),
        );
      },
    );

    test('post-save handoff tells user to return when similar happens', () {
      expect(
        PostSaveReturnHandoffCopy.afterFirstSaveTitle,
        'Come back when this shows up again.',
      );
      expect(
        EarlyRepeatProgressCopy.twoRelatedBody,
        'One more related moment unlocks your first proof.',
      );
      expect(PostSaveReturnCheckAnswerCopy.footer, 'One tap is enough.');
    });
  });

  group('Pro value preview copy', () {
    test(
      'pro preview mentions first repeat free and longer proof trail value',
      () {
        expect(
          ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
          allOf(
            contains('Your first repeat is free'),
            contains('longer proof trail'),
            contains('returns'),
            contains('changes'),
          ),
        );
        expect(
          ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
          containsAll([
            'Longer proof trail',
            'What returned and changed',
            'Correction history',
            'Continuity over time',
          ]),
        );
        expect(
          ArchiveBeliefThreadCopy.whyPro,
          'ArchiveMe becomes more useful as the evidence trail grows.',
        );
        expect(
          PrivateArchiveReportCopy.previewBody.toLowerCase(),
          contains('your first repeat'),
        );
      },
    );
  });
}

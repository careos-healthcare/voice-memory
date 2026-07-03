import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_why_appeared_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/voicememory_colors.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_moment_card.dart';

FirstProofMoment _sampleMoment({
  List<String> evidencePhrases = const ['said yes'],
}) =>
    FirstProofMoment(
      primaryLabel: FirstProofMomentCopy.primaryLabel,
      title: FirstProofMomentCopy.title,
      body: FirstProofMomentCopy.bodyStrong,
      evidenceLabel: FirstProofMomentCopy.evidenceLabel,
      evidencePhrases: evidencePhrases,
      whyLine: FirstProofMomentCopy.whyLine,
      nextLine: FirstProofMomentCopy.nextLine,
      hasStrongEvidence: true,
      usesPhraseBody: true,
    );

JournalEntry _entry(String id, String transcript) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 30,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: 'pattern',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: 'signal',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        '1',
        'I had no capacity but I said yes again to the extra meeting today.',
      ),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
      ),
    ];

void main() {
  group('FirstProofMomentCard evidence affordance', () {
    testWidgets('evidence label does not use link-blue styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: _sampleMoment(), entryCount: 3),
          ),
        ),
      );

      final labelFinder = find.byKey(
        const Key('first_proof_moment_evidence_label'),
      );
      expect(labelFinder, findsOneWidget);

      final text = tester.widget<Text>(labelFinder);
      expect(text.style?.color, AppColors.textSecondary);
      expect(text.style?.color, isNot(VoiceMemoryColors.primaryIndigo));
    });

    testWidgets('tapping evidence label reveals why-this-appeared body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: _sampleMoment(), entryCount: 3),
          ),
        ),
      );

      final whyBody = ProofSurfaceWhyAppearedCopy.line(
        ProofSurfaceWhyAppearedCopy.firstProof,
      );
      expect(find.text(whyBody), findsNothing);

      await tester.tap(
        find.byKey(const Key('first_proof_moment_evidence_label_tap')),
      );
      await tester.pump();

      expect(find.text(whyBody), findsOneWidget);
    });

    testWidgets('tapping evidence chip reveals why-this-appeared body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(
              moment: _sampleMoment(evidencePhrases: const ['said yes again']),
              entryCount: 3,
            ),
          ),
        ),
      );

      final whyBody = ProofSurfaceWhyAppearedCopy.line(
        ProofSurfaceWhyAppearedCopy.firstProof,
      );
      expect(find.text(whyBody), findsNothing);

      await tester.tap(find.text('said yes again'));
      await tester.pump();

      expect(find.text(whyBody), findsOneWidget);
    });

    testWidgets('why this appeared link still toggles explanation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: _sampleMoment(), entryCount: 3),
          ),
        ),
      );

      final whyBody = ProofSurfaceWhyAppearedCopy.line(
        ProofSurfaceWhyAppearedCopy.firstProof,
      );
      expect(find.text(whyBody), findsNothing);

      await tester.tap(find.text(ProofSurfaceWhyAppearedCopy.linkLabel));
      await tester.pump();
      expect(find.text(whyBody), findsOneWidget);

      await tester.tap(find.text(ProofSurfaceWhyAppearedCopy.linkLabel));
      await tester.pump();
      expect(find.text(whyBody), findsNothing);
    });

    testWidgets('shows only one why-this-appeared link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: _sampleMoment(), entryCount: 3),
          ),
        ),
      );

      expect(find.text(ProofSurfaceWhyAppearedCopy.linkLabel), findsOneWidget);
    });
  });

  group('FirstProofMomentCard proof flow', () {
    test('first proof still appears after three related entries', () {
      final moment = FirstProofMomentEngine.build(entries: _threeRelatedEntries());
      expect(moment, isNotNull);
      expect(moment!.title, FirstProofMomentCopy.title);
      expect(moment.evidencePhrases, isNotEmpty);
    });
  });

  group('First proof post-save completion copy', () {
    test('dedupes one-piece and one-more-piece microcopy strings', () {
      expect(
        VisibleArchiveProofCopy.oneEntryAddedTodayLine,
        'You added one piece today.',
      );
      expect(
        ArchiveProofCounter.onePieceTodayLine,
        'You added one more piece today.',
      );
      expect(
        VisibleArchiveProofCopy.oneEntryAddedTodayLine,
        isNot(equals(ArchiveProofCounter.onePieceTodayLine)),
      );
    });
  });
}

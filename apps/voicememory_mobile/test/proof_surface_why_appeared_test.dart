import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_why_appeared_copy.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_copy.dart';
import 'package:voicememory_mobile/features/early_archive/what_changed_since_last_time_model.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_model.dart';
import 'package:voicememory_mobile/features/early_archive/helpful_action_appeared_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/what_changed_since_last_time_card.dart';
import 'package:voicememory_mobile/widgets/proof/proof_surface_why_appeared_disclosure.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_moment_card.dart';

void _expectNoAdviceLanguage(String copy) {
  for (final phrase in ProofSurfaceAdviceGuard.bannedAdvicePhrases) {
    expect(
      copy.toLowerCase(),
      isNot(contains(phrase)),
      reason: 'must not contain "$phrase"',
    );
  }
  expect(copy.toLowerCase(), isNot(contains('therapy')));
  expect(copy.toLowerCase(), isNot(contains('diagnosis')));
  expect(copy.toLowerCase(), isNot(contains('this means')));
  expect(copy.toLowerCase(), isNot(contains('you always')));
}

void main() {
  group('ProofSurfaceWhyAppearedCopy', () {
    test('lines use Why this appeared prefix and evidence-based wording', () {
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.firstProof,
        ),
        'Why this appeared: ArchiveMe saw related evidence across three moments.',
      );
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.archiveBelief,
        ),
        contains('provisional belief'),
      );
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.whatChanged,
        ),
        contains('first proof'),
      );
    });

    test('copy avoids therapy advice personality and this means language', () {
      for (final line in ProofSurfaceWhyAppearedCopy.allLines) {
        _expectNoAdviceLanguage(line);
      }
    });

    test('does not duplicate primary proof card titles', () {
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.patternChanged,
        ),
        isNot(contains(PatternChangedCopy.title)),
      );
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.helpfulAction,
        ),
        isNot(contains(HelpfulActionAppearedCopy.title)),
      );
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.whatChanged,
        ),
        isNot(contains(WhatChangedSinceLastTimeCopy.title)),
      );
      expect(
        ProofSurfaceWhyAppearedCopy.line(
          ProofSurfaceWhyAppearedCopy.firstProof,
        ),
        isNot(contains(FirstProofMomentCopy.title)),
      );
    });
  });

  group('ProofSurfaceWhyAppearedDisclosure', () {
    testWidgets('starts collapsed and reveals body on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProofSurfaceWhyAppearedDisclosure(
              body: ProofSurfaceWhyAppearedCopy.whatChanged,
              surfaceKey: 'test',
            ),
          ),
        ),
      );

      expect(find.text(ProofSurfaceWhyAppearedCopy.linkLabel), findsOneWidget);
      expect(
        find.text(
          ProofSurfaceWhyAppearedCopy.line(
            ProofSurfaceWhyAppearedCopy.whatChanged,
          ),
        ),
        findsNothing,
      );

      await tester.tap(find.text(ProofSurfaceWhyAppearedCopy.linkLabel));
      await tester.pump();

      expect(
        find.text(
          ProofSurfaceWhyAppearedCopy.line(
            ProofSurfaceWhyAppearedCopy.whatChanged,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('Proof surface cards include why disclosure link', () {
    testWidgets('first proof moment card shows collapsed why link', (
      tester,
    ) async {
      final moment = FirstProofMoment(
        primaryLabel: FirstProofMomentCopy.primaryLabel,
        title: FirstProofMomentCopy.title,
        body: FirstProofMomentCopy.bodyStrong,
        evidenceLabel: FirstProofMomentCopy.evidenceLabel,
        evidencePhrases: const ['said yes again'],
        whyLine: FirstProofMomentCopy.whyLine,
        nextLine: FirstProofMomentCopy.nextLine,
        hasStrongEvidence: true,
        usesPhraseBody: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: moment, entryCount: 3),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('proof_surface_why_appeared_link_first_proof_moment'),
        ),
        findsOneWidget,
      );
      expect(find.text(FirstProofMomentCopy.title), findsOneWidget);
    });

    testWidgets('what changed card shows why link without transcript dump', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhatChangedSinceLastTimeCard(
              entryCount: 4,
              result: WhatChangedSinceLastTime(
                title: WhatChangedSinceLastTimeCopy.title,
                summary: WhatChangedSinceLastTimeCopy.softerSummary,
                evidenceLabel: WhatChangedSinceLastTimeCopy.evidenceLabel,
                evidenceRows: const [],
                footer: WhatChangedSinceLastTimeCopy.footer,
                state: ReturnCheckPayoffComparisonState.softer,
                hasPhrase: false,
                hasConfirmedRepeat: true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key(
            'proof_surface_why_appeared_link_what_changed_since_last_time',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(ProofSurfaceWhyAppearedCopy.linkLabel), findsOneWidget);
    });
  });
}

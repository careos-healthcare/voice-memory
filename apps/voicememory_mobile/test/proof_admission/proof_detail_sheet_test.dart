import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/proof_admission/evidence_verifier.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:voicememory_mobile/security/user_content_safety.dart';
import 'package:voicememory_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/proof/proof_detail_sheet.dart';
import 'package:voicememory_mobile/widgets/record/post_save_belief_insight.dart';

const _allHeadings = [
  ProofDetailSheet.supportingHeading,
  ProofDetailSheet.againstHeading,
  ProofDetailSheet.frequencyHeading,
  ProofDetailSheet.changeHeading,
  ProofDetailSheet.occurrenceHeading,
  ProofDetailSheet.missingHeading,
  ProofDetailSheet.correctionsHeading,
];

void main() {
  testWidgets('a fully populated proof renders every section heading', (
    tester,
  ) async {
    await _pumpSheet(tester, _fullView());

    expect(find.text(_fullView().statement), findsOneWidget);
    expect(find.text('Medium certainty'), findsOneWidget);
    for (final heading in _allHeadings) {
      expect(find.text(heading), findsOneWidget, reason: 'missing $heading');
    }
    expect(find.text(ProofDetailSheet.earlierMomentLabel), findsOneWidget);
    expect(find.text(ProofDetailSheet.latestMomentLabel), findsOneWidget);
  });

  testWidgets(
    'a minimal proof renders only the statement and its supporting evidence',
    (tester) async {
      await _pumpSheet(tester, _minimalView());

      expect(find.text('You paused before answering.'), findsOneWidget);
      expect(find.text(ProofDetailSheet.supportingHeading), findsOneWidget);
      expect(find.textContaining('paused for a second'), findsOneWidget);

      for (final heading in _allHeadings.where(
        (heading) => heading != ProofDetailSheet.supportingHeading,
      )) {
        expect(find.text(heading), findsNothing, reason: 'stray $heading');
      }
      expect(find.text(ProofDetailSheet.earlierMomentLabel), findsNothing);
      expect(find.text(ProofDetailSheet.latestMomentLabel), findsNothing);
      expect(find.text(ProofDetailSheet.staleNote), findsNothing);
      expect(find.textContaining('Not enough'), findsNothing);
    },
  );

  testWidgets('counterexamples and contradictions are always rendered', (
    tester,
  ) async {
    await _pumpSheet(tester, _fullView());

    expect(find.text(ProofDetailSheet.againstHeading), findsOneWidget);
    expect(find.textContaining('decided without looking'), findsOneWidget);
    expect(find.textContaining('the numbers do not matter'), findsOneWidget);
    expect(find.byKey(const Key('proof_detail_against_0')), findsOneWidget);
    expect(find.byKey(const Key('proof_detail_against_1')), findsOneWidget);
  });

  testWidgets('never renders a percentage, a score, or a ranking position', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpSheet(tester, _fullView());

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join(' ')
        .toLowerCase();

    expect(rendered, isNot(contains('%')));
    expect(rendered, isNot(contains('score')));
    expect(rendered, isNot(contains('rank')));
    expect(rendered, isNot(contains('rating')));
    expect(rendered, isNot(contains('out of')));
    expect(
      find.bySemanticsLabel(
        RegExp('%|score|rank|rating', caseSensitive: false),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('tapping an evidence row reports its source entry id', (
    tester,
  ) async {
    final opened = <String>[];
    await _pumpSheet(tester, _fullView(), onOpenEvidence: opened.add);

    await tester.tap(find.byKey(const Key('proof_detail_supporting_1')));
    await tester.pump();
    expect(opened, ['entry-2']);

    await tester.tap(find.byKey(const Key('proof_detail_against_0')));
    await tester.pump();
    expect(opened, ['entry-2', 'entry-3']);
  });

  testWidgets('evidence rows meet the minimum tap target', (tester) async {
    await _pumpSheet(tester, _fullView(), onOpenEvidence: (_) {});

    for (final key in [
      'proof_detail_supporting_0',
      'proof_detail_against_0',
      'proof_detail_then',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(ProofDetailSheet.minTapTarget));
      expect(size.width, greaterThanOrEqualTo(ProofDetailSheet.minTapTarget));
    }
  });

  testWidgets('renders without overflow at double text size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ProofDetailSheet(proof: _fullView(), onOpenEvidence: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('proof_detail_scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('headings and evidence rows carry screen-reader labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpSheet(tester, _fullView(), onOpenEvidence: (_) {});

    for (final heading in _allHeadings) {
      expect(
        find.bySemanticsLabel(heading),
        findsOneWidget,
        reason: '$heading is not reachable by a screen reader',
      );
    }
    expect(
      find.bySemanticsLabel(
        'Moment from 1 Jun 2026. checked the numbers first',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Moment from 10 Jul 2026. decided without looking'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('${ProofDetailSheet.earlierMomentLabel}\\. Moment from'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets(
    'the post-save card stays compact and defers detail to the sheet',
    (tester) async {
      ArchiveCorrectionStore.resetForTest();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostSaveBeliefInsight(
                entries: [_entry()],
                gate: const ProofDisplayGate(
                  activeArchiveScope: 'archive-1',
                  activeOwnerScope: 'owner-1',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('post_save_statement')), findsOneWidget);
      expect(find.byKey(const Key('post_save_evidence_quote')), findsOneWidget);
      expect(find.text('1 Jun 2026'), findsOneWidget);
      expect(
        find.text(PostSaveBeliefInsight.proofDetailsCta),
        findsOneWidget,
        reason: 'the card needs exactly one way into the detail sheet',
      );

      for (final heading in _allHeadings) {
        expect(
          find.text(heading),
          findsNothing,
          reason: '$heading belongs in the sheet, not on the card',
        );
      }
      expect(find.textContaining('verified moments'), findsNothing);
      expect(find.textContaining('coming up more often'), findsNothing);
      expect(
        find.textContaining('Needs another separate moment'),
        findsNothing,
      );
      expect(find.textContaining('recurring reference'), findsNothing);

      await tester.tap(find.byKey(const Key('post_save_proof_details')));
      await tester.pumpAndSettle();

      expect(find.text(ProofDetailSheet.supportingHeading), findsOneWidget);
      expect(find.text(ProofDetailSheet.frequencyHeading), findsOneWidget);
      expect(find.text('Was this right?'), findsWidgets);
    },
  );
}

Future<void> _pumpSheet(
  WidgetTester tester,
  VerifiedProofViewModel proof, {
  ValueChanged<String>? onOpenEvidence,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProofDetailSheet(proof: proof, onOpenEvidence: onOpenEvidence),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

VerifiedProofEvidenceViewModel _evidence(
  String entryId,
  String quote,
  ProofEvidenceRole role,
  DateTime at,
) => VerifiedProofEvidenceViewModel(
  sourceEntryId: entryId,
  quote: quote,
  sourceDate: at,
  role: role,
);

VerifiedProofViewModel _fullView() => VerifiedProofViewModel(
  proofId: 'proof-1',
  statement: 'You check the numbers before deciding.',
  supportingEvidence: [
    _evidence(
      'entry-1',
      'checked the numbers first',
      ProofEvidenceRole.support,
      DateTime.utc(2026, 6, 1),
    ),
    _evidence(
      'entry-2',
      'read the whole report before replying',
      ProofEvidenceRole.support,
      DateTime.utc(2026, 7, 4),
    ),
  ],
  counterexamples: [
    _evidence(
      'entry-3',
      'decided without looking',
      ProofEvidenceRole.counterexample,
      DateTime.utc(2026, 7, 10),
    ),
  ],
  contradictions: [
    _evidence(
      'entry-4',
      'said the numbers do not matter',
      ProofEvidenceRole.contradiction,
      DateTime.utc(2026, 7, 20),
    ),
  ],
  confidenceLabel: 'Medium certainty',
  frequencyLine: 'Seen in 3 verified moments over 21 days.',
  trendLine: 'This has been coming up more often.',
  strengthLine: 'The evidence has become stronger.',
  firstOccurrence: DateTime.utc(2026, 6, 1),
  lastOccurrence: DateTime.utc(2026, 8, 1),
  missingEvidenceLines: const ['Needs another separate moment.'],
  correctionLines: const ['You corrected the wording.'],
  thenEvidence: _evidence(
    'entry-1',
    'checked the numbers first',
    ProofEvidenceRole.support,
    DateTime.utc(2026, 6, 1),
  ),
  nowEvidence: _evidence(
    'entry-2',
    'read the whole report before replying',
    ProofEvidenceRole.support,
    DateTime.utc(2026, 7, 4),
  ),
  stale: false,
);

VerifiedProofViewModel _minimalView() => VerifiedProofViewModel(
  proofId: 'proof-2',
  statement: 'You paused before answering.',
  supportingEvidence: [
    _evidence(
      'entry-9',
      'paused for a second',
      ProofEvidenceRole.support,
      DateTime.utc(2026, 8, 4),
    ),
  ],
  counterexamples: const [],
  contradictions: const [],
  confidenceLabel: 'Low certainty',
  frequencyLine: null,
  trendLine: null,
  strengthLine: null,
  firstOccurrence: null,
  lastOccurrence: null,
  missingEvidenceLines: const [],
  correctionLines: const [],
  thenEvidence: null,
  nowEvidence: null,
  stale: false,
);

// The card revalidates its stored proof against the live entry before showing
// it, so this fixture has to be internally consistent the way a real admitted
// proof is: the quote must sit at the recorded span of this exact transcript,
// and the revision and fingerprint must be the ones that transcript produces.
const _transcript = 'I checked the numbers first before deciding.';
const _quote = 'checked the numbers first';
final _quoteStart = _transcript.indexOf(_quote);

JournalEntry _entry() {
  final at = DateTime.utc(2026, 6, 1);
  const reflection = Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: 'checked the numbers first',
    concreteObservation: 'You check the numbers before deciding.',
    repeatedSignal: '',
  );
  return JournalEntry(
    id: 'entry-1',
    createdAt: at,
    transcript: _transcript,
    durationSeconds: 30,
    reflection: reflection,
    verifiedProof: VerifiedProof(
      proofId: 'proof-1',
      archiveScope: 'archive-1',
      ownerScope: 'owner-1',
      reflection: reflection,
      claims: [
        VerifiedProofClaim(
          claimId: 'main',
          kind: ProofClaimKind.mainObservation,
          text: reflection.concreteObservation,
          evidence: [_snapshot('entry-1', 'checked the numbers first', at)],
        ),
      ],
      confidenceBand: ProofConfidenceBand.medium,
      qualityReceipt: ProofQualityReceipt(
        proofType: ProofType.repeatedSignal,
        confidenceBand: ProofConfidenceBand.medium,
        frequency: ProofFrequency(
          distinctMoments: 3,
          windowStart: at,
          windowEnd: DateTime.utc(2026, 6, 22),
        ),
        trend: ProofTrend.increasing,
        strengthOverTime: ProofStrengthOverTime.stronger,
        supportingEvidence: [
          _snapshot('entry-1', 'checked the numbers first', at),
          _snapshot(
            'entry-2',
            'read the whole report before replying',
            DateTime.utc(2026, 6, 22),
          ),
        ],
        counterexamples: const [],
        contradictions: const [],
        missingEvidence: const [
          MissingEvidenceReason.needsAnotherDistinctSource,
        ],
        firstOccurrence: at,
        lastOccurrence: DateTime.utc(2026, 6, 22),
        verifierVersion: 1,
        scorerVersion: 1,
        configVersion: 1,
        generatedAt: DateTime.utc(2026, 6, 22),
      ),
      verifiedAt: at,
      sourceRevisionFingerprint: 'source-revision-fingerprint',
      proofFingerprint: 'proof-fingerprint',
      semanticFramingFingerprint: 'semantic-fingerprint',
      wordingFingerprint: 'wording-fingerprint',
    ),
  );
}

VerifiedEvidenceSnapshot _snapshot(String entryId, String quote, DateTime at) {
  final start = quote == _quote ? _quoteStart : 0;
  return VerifiedEvidenceSnapshot(
    sourceEntryId: entryId,
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    transcriptRevision: UserContentSafety.privacyHash(_transcript),
    transcriptFingerprint: CanonicalEvidenceVerifier.transcriptFingerprint(
      _transcript,
    ),
    sourceDate: at,
    sourceType: ProofSourceType.userTyped,
    quote: quote,
    startUtf16: start,
    endUtf16: start + quote.length,
    role: ProofEvidenceRole.support,
    verifiedAt: at,
  );
}

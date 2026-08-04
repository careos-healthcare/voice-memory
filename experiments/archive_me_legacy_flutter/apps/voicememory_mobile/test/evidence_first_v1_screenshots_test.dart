import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_home/archive_journal_home.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_widgets.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/belief_changes_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

final _receipt = ExplainableConclusion(
  id: 'review-receipt',
  statement: 'In this moment, you described pausing before answering.',
  confidence: 68,
  reasoning: const [
    'The saved words directly describe a pause before responding.',
    'ArchiveMe selected one bounded observation rather than a broad pattern.',
  ],
  uncertaintyNote: 'One moment does not show whether this will repeat.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'review-entry',
      quote: 'I paused before answering',
      startUtf16: 0,
      endUtf16: 25,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 7, 30),
      sourceType: EvidenceSourceType.text,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The pause may have been specific to this situation.',
      rationale: 'The surrounding context may explain the response.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'review_fixture',
    generatedAt: DateTime.utc(2026, 7, 30, 1),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  nextRecordingPrompt: 'What happens the next time you need to answer quickly?',
);

final _change = ExplainableConclusion(
  id: 'review-change',
  statement: 'Recent entries place less urgency on answering immediately.',
  confidence: 80,
  reasoning: const [
    'The recent moment describes waiting where the earlier moment did not.',
  ],
  uncertaintyNote: 'Two moments suggest change but do not prove a trend.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'then',
      quote: 'I answered immediately',
      startUtf16: 0,
      endUtf16: 22,
      role: TranscriptEvidenceRole.supporting,
      temporalRole: EvidenceTemporalRole.then,
      sourceCapturedAt: DateTime.utc(2026, 6, 1),
      sourceType: EvidenceSourceType.voice,
    ),
    TranscriptEvidenceCitation(
      entryId: 'now',
      quote: 'I waited before answering',
      startUtf16: 0,
      endUtf16: 25,
      role: TranscriptEvidenceRole.supporting,
      temporalRole: EvidenceTemporalRole.now,
      sourceCapturedAt: DateTime.utc(2026, 7, 30),
      sourceType: EvidenceSourceType.text,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The situations may have been different.',
      rationale: 'Context could explain the different response.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'review_fixture',
    generatedAt: DateTime.utc(2026, 7, 31),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  kind: ExplainableInsightKind.change,
);

void main() {
  testWidgets('generate evidence-first phone review artifacts', (tester) async {
    await _surface(tester, const Size(390, 844), _receiptSurface());
    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile(
        '../tool/screenshots/evidence_first_v1/receipt_phone.png',
      ),
    );

    await _surface(
      tester,
      const Size(390, 844),
      BeliefChangesScreen(
        previewReliableChange: _change,
        previewTranscripts: const {
          'then': 'I answered immediately',
          'now': 'I waited before answering',
        },
      ),
    );
    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile(
        '../tool/screenshots/evidence_first_v1/changes_then_now_phone.png',
      ),
    );

    await _surface(
      tester,
      const Size(390, 844),
      const BeliefChangesScreen(previewHasHistory: true),
    );
    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile(
        '../tool/screenshots/evidence_first_v1/changes_insufficient_phone.png',
      ),
    );

    await _surface(tester, const Size(390, 844), _archiveSurface());
    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile(
        '../tool/screenshots/evidence_first_v1/archive_journal_phone.png',
      ),
    );
  });

  testWidgets('generate tablet receipt at text scale 2', (tester) async {
    await _surface(
      tester,
      const Size(834, 1194),
      _receiptSurface(),
      textScale: 2,
    );
    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile(
        '../tool/screenshots/evidence_first_v1/receipt_tablet_text_2.png',
      ),
    );
  });
}

Widget _receiptSurface() {
  final gated = ExplainableConclusionRenderGate.visible(
    _receipt,
    canonicalTranscripts: const {
      'review-entry': 'I paused before answering the message.',
    },
  )!;
  return Scaffold(
    appBar: AppBar(title: const Text('Saved moment')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('I paused before answering the message.'),
        const SizedBox(height: 16),
        ExplainableConclusionCard(conclusion: gated),
      ],
    ),
  );
}

Widget _archiveSurface() => ArchiveJournalHome(
  entries: [
    JournalEntry(
      id: 'newer',
      createdAt: DateTime.utc(2026, 7, 30),
      transcript: 'I waited before answering the message today.',
      durationSeconds: 0,
      reflection: const Reflection(
        mood: 'steady',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    ),
    JournalEntry(
      id: 'older',
      createdAt: DateTime.utc(2026, 7, 28),
      transcript: 'I answered quickly and felt rushed afterward.',
      durationSeconds: 18,
      localAudioVaultRef: 'vault:older',
      reflection: const Reflection(
        mood: 'steady',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    ),
  ],
  onRefresh: () async {},
  onOpenMoment: (_) {},
  onSearch: () {},
  onOpenInsights: () {},
  onRecord: () {},
);

Future<void> _surface(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child is Scaffold ? child : Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

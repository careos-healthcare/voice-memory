import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_intelligence_presentation.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(int index, String transcript, {bool withAudio = true}) {
  return JournalEntry(
    id: 'entry-$index',
    createdAt: DateTime(2026, 7, 20 + index),
    transcript: transcript,
    durationSeconds: 20,
    localAudioPath: withAudio ? '/vault/entry-$index.enc' : null,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: ['capacity'],
      exactLanguagePattern: '',
      concreteObservation: 'Capacity pressure appeared in this moment.',
      repeatedSignal: '',
    ),
  );
}

ArchiveBeliefCardModel _belief({
  ArchiveBeliefSection section = ArchiveBeliefSection.changing,
  required List<String> quotes,
}) {
  return ArchiveBeliefCardModel(
    id: 'capacity-belief',
    statement: 'I tend to agree before checking my available capacity.',
    confidencePercent: 72,
    evidenceSummary: 'Several saved moments mention agreeing under pressure.',
    whyExplanation:
        'The same decision point appears across the linked saved moments.',
    section: section,
    timeline: [
      for (var i = 0; i < quotes.length; i++)
        BeliefEvidenceQuote(periodLabel: 'Moment ${i + 1}', quote: quotes[i]),
    ],
    conclusion: 'This response appears less automatic in recent moments.',
  );
}

ArchiveBeliefsSnapshot _snapshot(ArchiveBeliefCardModel belief) {
  return ArchiveBeliefsSnapshot(
    homeBeliefs: [belief],
    current: belief.section == ArchiveBeliefSection.current
        ? [belief]
        : const [],
    emerging: belief.section == ArchiveBeliefSection.emerging
        ? [belief]
        : const [],
    changing: belief.section == ArchiveBeliefSection.changing
        ? [belief]
        : const [],
    hiddenPatterns: const [],
    stats: const ArchiveBeliefStats(
      beliefsIdentified: 1,
      strongestBelief: 'capacity-belief',
      archiveAgeDays: 10,
      reflectionsAnalysed: 5,
      evidencePoints: 5,
    ),
  );
}

void main() {
  final transcripts = [
    'I agreed to the extra meeting before checking whether I had capacity.',
    'I paused before answering and checked what was already on my calendar.',
    'I noticed pressure to say yes even though the week was already full.',
    'I asked for time before committing to another deadline at work.',
    'I declined the request after checking the work I had already accepted.',
  ];
  final entries = [
    for (var i = 0; i < transcripts.length; i++) _entry(i, transcripts[i]),
  ];

  test('normal archive has exactly four primary sections in order', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(_belief(quotes: transcripts)),
    );

    expect(presentation.isEmpty, isFalse);
    expect(
      presentation.sections.map((section) => section.id).toList(),
      ArchiveIntelligencePresentation.sectionOrder,
    );
  });

  test('empty archive produces one coherent empty presentation', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: const [],
      beliefs: null,
    );

    expect(presentation.isEmpty, isTrue);
    expect(presentation.sections, hasLength(1));
    expect(
      presentation.sections.single.state,
      ArchiveIntelligenceSectionState.empty,
    );
  });

  test('low evidence remains cautious', () {
    final repeatedQuote = transcripts.first;
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(_belief(quotes: List.filled(5, repeatedQuote))),
    );

    final reasoning = presentation.section(
      ArchiveIntelligenceSectionId.reasoning,
    )!;
    expect(reasoning.state, ArchiveIntelligenceSectionState.lowEvidence);
    expect(reasoning.confidenceExplanation, contains('early read'));
    expect(reasoning.confidenceExplanation, contains('may change'));
  });

  test('supporting moments never invent unmatched evidence', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(
        _belief(quotes: List.filled(5, 'Words that are not in any entry.')),
      ),
    );

    final support = presentation.section(
      ArchiveIntelligenceSectionId.supportingMoments,
    )!;
    expect(support.moments, isEmpty);
    expect(support.state, ArchiveIntelligenceSectionState.pending);
  });

  test('duplicate evidence resolves to one stable source moment', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(_belief(quotes: List.filled(5, transcripts.first))),
    );

    final moments = presentation
        .section(ArchiveIntelligenceSectionId.supportingMoments)!
        .moments;
    expect(moments, hasLength(1));
    expect(moments.single.id, 'moment:entry-0');
    expect(moments.single.entryId, 'entry-0');
  });

  test('absent change data does not create a fake change', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(
        _belief(section: ArchiveBeliefSection.current, quotes: transcripts),
      ),
    );

    final change = presentation.section(
      ArchiveIntelligenceSectionId.whatChanged,
    )!;
    expect(change.state, ArchiveIntelligenceSectionState.pending);
    expect(change.headline, isNull);
    expect(change.body, contains('not enough reliable history'));
  });

  test('administrative controls cannot enter the presentation', () {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: entries,
      beliefs: _snapshot(_belief(quotes: transcripts)),
    );
    final text = presentation.sections
        .expand(
          (section) => [
            section.title,
            section.body,
            section.headline,
            section.actionLabel,
          ],
        )
        .whereType<String>()
        .join(' ')
        .toLowerCase();

    expect(
      ArchiveIntelligencePresentation.sectionOrder,
      ArchiveIntelligenceSectionId.values,
    );
    for (final excluded in [
      'backup',
      'restore',
      'pro bridge',
      'beta feedback',
      'check-in setup',
      'weekly report',
      'monthly report',
    ]) {
      expect(text, isNot(contains(excluded)));
    }
  });

  test('presentation model has no Flutter widget dependency', () {
    final source = File(
      'lib/features/archive_home/archive_intelligence_presentation.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('Widget')));
    expect(source, isNot(contains('BuildContext')));
  });
}

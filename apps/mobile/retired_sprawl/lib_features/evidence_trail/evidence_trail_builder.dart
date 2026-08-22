import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

const _engine = ArchiveExplanationEngine();

/// Builds [EvidenceTrailPayload] from existing archive engines — no AI.
EvidenceTrailPayload? buildEvidenceTrailForInsight({
  required ArchiveInsightRef ref,
  required List<JournalEntry> entries,
  ArchiveStateObjectV3? state,
  String? askPrompt,
  List<String>? askCitedEntryIds,
}) {
  final explanation = _engine.buildExplanation(
    ref: ref,
    entries: entries,
    state: state,
    askPromptAnswer: askPrompt,
    askCitedIds: askCitedEntryIds,
  );
  if (explanation == null) return null;
  return _fromExplanation(explanation);
}

EvidenceTrailPayload? buildEvidenceTrailForArchiveV1(ArchiveV1View view) {
  final theory = view.theory;
  final belief = view.belief;
  if (theory == null && belief == null) return null;

  final supporting = belief?.supportingEntries ?? view.eligibleEntries;
  final sources = _sourcesFromEntries(
    supporting,
  );

  return EvidenceTrailPayload(
    title: theory?.statement ?? belief?.statement ?? 'Archive theory',
    whySummary:
        'This conclusion is drawn from ${theory?.evidenceCount ?? belief?.evidenceCount ?? sources.length} '
        'supporting recordings in your archive.',
    evidenceCount:
        theory?.evidenceCount ?? belief?.evidenceCount ?? sources.length,
    confidencePercent: theory?.confidencePercent ?? belief?.confidencePercent,
    confidenceFactors: [
      if (theory != null) ...[
        EvidenceConfidenceFactor(
          label: 'Confidence',
          value: '${theory.confidencePercent}%',
        ),
        EvidenceConfidenceFactor(
          label: 'Supporting recordings',
          value: '${theory.evidenceCount}',
        ),
        EvidenceConfidenceFactor(
          label: 'Counter-evidence',
          value: '${theory.counterEvidenceCount}',
        ),
      ],
    ],
    sources: sources,
  );
}

EvidenceTrailPayload buildEvidenceTrailForChangeBelief({
  required ArchiveChangeBeliefRow row,
  required List<JournalEntry> entries,
}) {
  final supporting = _recentEligible(entries, row.evidenceCount);
  return EvidenceTrailPayload(
    title: row.statement,
    whySummary:
        'Confidence appears to have moved from ${row.confidenceBefore}% to '
        '${row.confidenceNow}% across ${row.evidenceCount} supporting recordings.',
    evidenceCount: row.evidenceCount,
    confidencePercent: row.confidenceNow,
    confidenceFactors: [
      EvidenceConfidenceFactor(
        label: 'Confidence change',
        value: '${row.confidenceBefore}% → ${row.confidenceNow}%',
      ),
      EvidenceConfidenceFactor(
        label: 'Supporting recordings',
        value: '${row.evidenceCount}',
      ),
      EvidenceConfidenceFactor(
        label: 'Counter-evidence',
        value: '${row.counterEvidenceCount}',
      ),
    ],
    sources: _sourcesFromEntries(supporting),
  );
}

EvidenceTrailPayload buildEvidenceTrailForChangeContradiction({
  required ArchiveChangeContradictionRow row,
  required List<JournalEntry> entries,
}) {
  final related = _recentEligible(entries, row.evidenceCount.clamp(2, 6));
  return EvidenceTrailPayload(
    title: 'Contradiction noticed',
    whySummary:
        'Two ways of talking about the same theme appear in your recent archive. '
        'This may be a tension worth revisiting — not a final judgment.',
    evidenceCount: row.evidenceCount,
    confidencePercent: row.confidenceScore,
    confidenceFactors: [
      EvidenceConfidenceFactor(
        label: 'Contradiction strength',
        value: '${row.confidenceScore}%',
      ),
      EvidenceConfidenceFactor(
        label: 'Related recordings',
        value: '${related.length}',
      ),
    ],
    sources: _sourcesFromEntries(related, role: EvidenceSourceRole.related),
  );
}

EvidenceTrailPayload buildEvidenceTrailForChangeTheme({
  required ArchiveChangeThemeRow row,
  required List<JournalEntry> entries,
}) {
  final related = _entriesMentioningTheme(entries, row.label, row.mentionsNow);
  return EvidenceTrailPayload(
    title: row.label,
    whySummary:
        '${row.label} appears in ${row.mentionsNow} recordings '
        '(+${row.newMentionsSinceReview} since your last review).',
    evidenceCount: row.mentionsNow,
    confidenceFactors: [
      EvidenceConfidenceFactor(
        label: 'Mentions now',
        value: '${row.mentionsNow}',
      ),
      EvidenceConfidenceFactor(
        label: 'New since review',
        value: '${row.newMentionsSinceReview}',
      ),
    ],
    sources: _sourcesFromEntries(related),
  );
}

EvidenceTrailPayload? buildEvidenceTrailForV1Contradiction({
  required ArchiveV1Contradiction contradiction,
  required List<JournalEntry> entries,
}) {
  final byId = {for (final e in entries) e.id: e};
  final matched = [
    for (final id in contradiction.entryIds)
      if (byId[id] != null) byId[id]!,
  ];
  final sources = matched.isNotEmpty
      ? _sourcesFromEntries(matched, role: EvidenceSourceRole.related)
      : _sourcesFromEntries(
          _recentEligible(entries, 4),
          role: EvidenceSourceRole.related,
        );

  return EvidenceTrailPayload(
    title: 'Contradiction',
    whySummary:
        'These recordings use different language about the same area. '
        'The archive surfaces this so you can compare them — not to decide which is “right.”',
    evidenceCount: sources.length,
    confidencePercent: contradiction.confidenceScore,
    confidenceFactors: [
      EvidenceConfidenceFactor(
        label: 'Confidence',
        value: '${contradiction.confidenceScore}%',
      ),
      EvidenceConfidenceFactor(
        label: 'Recordings linked',
        value: '${sources.length}',
      ),
    ],
    sources: sources,
  );
}

EvidenceTrailPayload _fromExplanation(ArchiveExplanation explanation) {
  final sources = <EvidenceTrailSource>[
    for (final e in explanation.supportingEvidence)
      EvidenceTrailSource(
        entryId: e.entryId,
        recordedAt: e.recordedAt,
        excerpt: e.excerpt,
      ),
    for (final e in explanation.contradictingEvidence)
      EvidenceTrailSource(
        entryId: e.entryId,
        recordedAt: e.recordedAt,
        excerpt: e.excerpt,
        role: EvidenceSourceRole.contradicting,
      ),
  ];

  final factors = <EvidenceConfidenceFactor>[
    EvidenceConfidenceFactor(
      label: 'Archive confidence',
      value: '${explanation.confidence.round()}%',
    ),
    EvidenceConfidenceFactor(
      label: 'Supporting excerpts',
      value: '${explanation.supportingEvidence.length}',
    ),
    if (explanation.contradictingEvidence.isNotEmpty)
      EvidenceConfidenceFactor(
        label: 'Contradicting excerpts',
        value: '${explanation.contradictingEvidence.length}',
      ),
  ];

  return EvidenceTrailPayload(
    title: explanation.title,
    whySummary: explanation.whySummary,
    evidenceCount: explanation.supportingEvidence.length,
    confidencePercent: explanation.confidence.round(),
    confidenceFactors: factors,
    sources: sources,
  );
}

List<EvidenceTrailSource> _sourcesFromEntries(
  List<JournalEntry> entries, {
  EvidenceSourceRole role = EvidenceSourceRole.supporting,
}) {
  final sorted = [...entries]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return [
    for (final e in sorted.take(12))
      EvidenceTrailSource(
        entryId: e.id,
        recordedAt: e.createdAt,
        excerpt: _excerpt(e),
        role: role,
      ),
  ];
}

List<JournalEntry> _recentEligible(List<JournalEntry> entries, int limit) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  final working = eligible.isNotEmpty
      ? eligible
      : entries.where((e) => e.transcript.trim().isNotEmpty).toList();
  if (working.isEmpty) return const [];
  return working.reversed.take(limit.clamp(1, 12)).toList().reversed.toList();
}

List<JournalEntry> _entriesMentioningTheme(
  List<JournalEntry> entries,
  String label,
  int limit,
) {
  final key = label.trim().toLowerCase();
  final matched = entries.where((e) {
    final blob = [
      e.transcript,
      ...e.reflection.recurringThemes,
    ].join(' ').toLowerCase();
    return blob.contains(key);
  }).toList();
  if (matched.isNotEmpty) {
    matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matched.take(limit.clamp(1, 12)).toList();
  }
  return _recentEligible(entries, limit);
}

String _excerpt(JournalEntry e) {
  final t = e.transcript.trim();
  if (t.isEmpty) {
    final obs = e.reflection.concreteObservation.trim();
    if (obs.isNotEmpty) return '“$obs”';
    return '(No transcript)';
  }
  final line = t.length > 160 ? '${t.substring(0, 160)}…' : t;
  return '“$line”';
}
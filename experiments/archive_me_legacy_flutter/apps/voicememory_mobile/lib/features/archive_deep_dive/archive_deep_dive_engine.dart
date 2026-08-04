import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import '../archive_analyst/archive_belief_visibility.dart';
import '../archive_analyst/topical_counter_evidence.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/belief_timeline_engine.dart';
import '../archive_explanations/cross_reference_engine.dart';
import '../archive_explanations/explanation_models.dart';
import '../archive_state_object/archive_state_object.dart';
import '../archive_v1/archive_v1_models.dart';
import 'archive_deep_dive_inquiry_engine.dart';
import 'archive_deep_dive_models.dart';

/// Composes Archive Deep Dive from [ArchiveV1View] and existing engines.
class ArchiveDeepDiveEngine {
  const ArchiveDeepDiveEngine({
    this.crossReferenceEngine = const CrossReferenceEngine(),
    this.beliefTimelineEngine = const BeliefTimelineEngine(),
    this.inquiryEngine = const ArchiveDeepDiveInquiryEngine(),
    this.topicalCounter = const TopicalCounterEvidence(),
  });

  final CrossReferenceEngine crossReferenceEngine;
  final BeliefTimelineEngine beliefTimelineEngine;
  final ArchiveDeepDiveInquiryEngine inquiryEngine;
  final TopicalCounterEvidence topicalCounter;

  ArchiveDeepDiveView? build({
    required ArchiveV1View v1,
    ArchiveStateObjectV3? state,
  }) {
    final belief = v1.belief;
    if (belief == null) return null;

    final statement = belief.statement.trim();
    if (statement.isEmpty) return null;

    if (!ArchiveBeliefVisibility.isVisibleBelief(
      statement: statement,
      confidencePercent: belief.confidencePercent,
      evidenceCount: belief.evidenceCount,
    )) {
      return null;
    }

    final eligible = v1.eligibleEntries;
    final supporting = belief.supportingEntries.isNotEmpty
        ? belief.supportingEntries
        : eligible.reversed.take(8).toList();

    final why = _buildWhy(belief, eligible, supporting);
    final beliefTimeline = beliefTimelineEngine.build(
      entries: eligible,
      beliefText: statement,
    );
    final history = _buildHistory(v1, beliefTimeline, supporting, statement);
    final patterns = _buildPatterns(v1, state, statement, supporting);
    final counter = _buildCounterEvidence(
      v1: v1,
      eligible: eligible,
      supporting: supporting,
      statement: statement,
    );
    final timeline = _buildTimeline(v1, eligible, supporting, beliefTimeline);
    final inquiries = inquiryEngine.build(
      v1: v1,
      hasDistinctEvolution: v1.thenNow?.hasDistinctEvolution ?? false,
      hasContradictions: v1.contradictions.isNotEmpty,
      beliefWeakening: beliefTimeline.trend == BeliefTimelineTrend.weakening,
      firstEvidenceAt:
          v1.thenNow?.firstEvidenceAt ?? eligible.firstOrNull?.createdAt,
    );

    return ArchiveDeepDiveView(
      beliefStatement: statement,
      confidencePercent: belief.confidencePercent,
      why: why,
      history: history,
      patterns: patterns,
      counterEvidence: counter,
      inquiryQuestions: inquiries,
      timeline: timeline,
      supportingEntries: supporting,
      evolutionTimeline: v1.evolutionTimeline,
    );
  }

  ArchiveDeepDiveWhySection _buildWhy(
    ArchiveV1Belief belief,
    List<JournalEntry> eligible,
    List<JournalEntry> supporting,
  ) {
    final summary =
        archiveWhyArchiveBelievesCopy(eligible) ??
        'The archive weighed ${belief.evidenceCount} saved moments with usable transcripts.';
    final excerpts = <ArchiveDeepDiveExcerpt>[];
    for (final e in supporting.take(6)) {
      excerpts.add(_excerptFrom(e));
    }
    return ArchiveDeepDiveWhySection(
      summaryLines: [summary],
      evidenceCount: belief.evidenceCount,
      supportingRecordings: supporting.length,
      excerptLines: excerpts,
    );
  }

  ArchiveDeepDiveBeliefHistory _buildHistory(
    ArchiveV1View v1,
    BeliefTimeline beliefTimeline,
    List<JournalEntry> supporting,
    String statement,
  ) {
    final thenNow = v1.thenNow;
    final evo = v1.evolutionTimeline;
    final firstEntry = supporting.isNotEmpty ? supporting.first : null;
    final latestEntry = supporting.isNotEmpty ? supporting.last : null;
    final peakEntry = _entryNearDate(supporting, beliefTimeline.firstSeen);

    final firstAt =
        thenNow?.firstEvidenceAt ??
        firstEntry?.createdAt ??
        beliefTimeline.firstSeen;
    final latestAt = thenNow?.latestEvidenceAt ?? latestEntry?.createdAt;

    final thenBelief =
        evo.firstBelief?.beliefText.trim() ?? thenNow?.thenBelief ?? statement;
    final nowBelief =
        evo.currentBelief?.beliefText.trim() ?? thenNow?.nowBelief ?? statement;

    return ArchiveDeepDiveBeliefHistory(
      firstAppearance: ArchiveDeepDiveAppearance(
        label: 'First appearance',
        beliefText: thenBelief,
        at: firstAt,
        strengthPercent: beliefTimeline.points.isNotEmpty
            ? beliefTimeline.points.first.strengthPercent
            : null,
      ),
      strongestAppearance: ArchiveDeepDiveAppearance(
        label: 'Strongest appearance',
        beliefText: statement,
        at: peakEntry?.createdAt ?? latestAt,
        strengthPercent: beliefTimeline.peakPercent,
      ),
      latestAppearance: ArchiveDeepDiveAppearance(
        label: 'Latest appearance',
        beliefText: nowBelief,
        at: latestAt,
        strengthPercent: beliefTimeline.currentPercent,
      ),
      thenSnapshot: ArchiveDeepDiveEvidenceSnapshot(
        beliefText: thenBelief,
        excerpt: firstEntry != null
            ? _quote(firstEntry.transcript)
            : 'No excerpt yet.',
        entryId: firstEntry?.id,
        dateLabel: firstAt != null ? formatUserFacingDate(firstAt) : null,
      ),
      nowSnapshot: ArchiveDeepDiveEvidenceSnapshot(
        beliefText: nowBelief,
        excerpt: latestEntry != null
            ? _quote(latestEntry.transcript)
            : 'No excerpt yet.',
        entryId: latestEntry?.id,
        dateLabel: latestAt != null ? formatUserFacingDate(latestAt) : null,
      ),
      hasDistinctEvolution: thenNow?.hasDistinctEvolution ?? evo.hasEvolution,
    );
  }

  ArchiveDeepDivePatternExplorer _buildPatterns(
    ArchiveV1View v1,
    ArchiveStateObjectV3? state,
    String statement,
    List<JournalEntry> supporting,
  ) {
    final entryIds = supporting.map((e) => e.id).toList();
    final cross = crossReferenceEngine.build(
      entries: v1.eligibleEntries,
      state: state,
      focusBelief: statement,
      focusEntryIds: entryIds,
    );

    final themes = cross.relatedThemes
        .map((t) => '${t.name} · ${t.frequency}× in archive')
        .toList();

    final contradictions = v1.contradictions
        .map(
          (c) => ArchiveDeepDiveConnectedInsight(
            kind: 'Contradiction',
            headline: c.kind == ArchiveV1ContradictionKind.themeGap
                ? 'Theme gap'
                : 'Conflicting statements',
            detail: '${c.youSay} — ${c.but}',
            entryIds: c.entryIds,
          ),
        )
        .toList();

    if (contradictions.isEmpty) {
      for (final c in cross.relatedContradictions.take(3)) {
        contradictions.add(
          ArchiveDeepDiveConnectedInsight(
            kind: 'Contradiction',
            headline: 'Related tension',
            detail: c.summary,
          ),
        );
      }
    }

    final blindSpots = v1.blindSpots
        .map(
          (b) => ArchiveDeepDiveConnectedInsight(
            kind: 'Blind spot',
            headline: b.headline,
            detail: '${b.observation} (${b.evidenceCount} recordings)',
            entryIds: b.entryIds,
          ),
        )
        .toList();

    if (blindSpots.isEmpty) {
      for (final b in cross.relatedBlindSpots.take(3)) {
        blindSpots.add(
          ArchiveDeepDiveConnectedInsight(
            kind: 'Blind spot',
            headline: b.headline,
            detail: 'Surfaced in pattern review on this device.',
          ),
        );
      }
    }

    return ArchiveDeepDivePatternExplorer(
      relatedThemes: themes.take(6).toList(),
      connectedContradictions: contradictions.take(4).toList(),
      connectedBlindSpots: blindSpots.take(4).toList(),
    );
  }

  ArchiveDeepDiveCounterEvidence _buildCounterEvidence({
    required ArchiveV1View v1,
    required List<JournalEntry> eligible,
    required List<JournalEntry> supporting,
    required String statement,
  }) {
    final forExcerpts = supporting.take(5).map(_excerptFrom).toList();

    final againstSummaries = <String>[];
    for (final c in v1.contradictions.take(3)) {
      againstSummaries.add('${c.youSay} — ${c.but}');
    }

    final contradictionIds = v1.contradictions
        .expand((c) => c.entryIds)
        .toSet();

    final rawCounters = topicalCounter.pickRaw(
      beliefText: statement,
      eligible: eligible,
      supporting: supporting,
      contradictionEntryIds: contradictionIds,
    );
    final cap = topicalCounter.cap(
      rawCounters: rawCounters,
      supportingCount: supporting.length,
    );

    final againstExcerpts = cap.capped
        .where(
          (e) => topicalCounter.isRelevantCounterQuote(
            beliefText: statement,
            counterQuote: e.transcript,
          ),
        )
        .toList()
        .reversed
        .take(4)
        .map(_excerptFrom)
        .toList();

    for (final e in cap.capped) {
      final tension = e.reflection.tensionOrContradiction?.trim() ?? '';
      if (tension.length >= 16) {
        againstSummaries.add('Tension noted: $tension');
      }
      if (againstSummaries.length >= 5) break;
    }

    return ArchiveDeepDiveCounterEvidence(
      forExcerpts: forExcerpts,
      againstExcerpts: againstExcerpts,
      againstSummaries: againstSummaries,
    );
  }

  ArchiveDeepDiveBeliefTimeline _buildTimeline(
    ArchiveV1View v1,
    List<JournalEntry> eligible,
    List<JournalEntry> supporting,
    BeliefTimeline beliefTimeline,
  ) {
    final first = eligible.isNotEmpty ? eligible.first : null;
    final latest = eligible.isNotEmpty ? eligible.last : null;

    ArchiveDeepDiveTimelineEvent? firstMention;
    if (first != null) {
      firstMention = ArchiveDeepDiveTimelineEvent(
        label: 'First mention',
        subtitle: _quote(first.transcript),
        entryId: first.id,
        at: first.createdAt,
      );
    }

    final keyRecordings = supporting
        .take(4)
        .map(
          (e) => ArchiveDeepDiveTimelineEvent(
            label: 'Supporting recording',
            subtitle: _quote(e.transcript),
            entryId: e.id,
            at: e.createdAt,
          ),
        )
        .toList();

    final evolutionEvents = <ArchiveDeepDiveTimelineEvent>[];
    for (final block in v1.evolutionTimeline.blocks) {
      evolutionEvents.add(
        ArchiveDeepDiveTimelineEvent(
          label: 'Belief version',
          subtitle: block.version.beliefText,
          at: DateTime.tryParse(block.version.recordedAt),
        ),
      );
    }
    if (beliefTimeline.peakLabel.isNotEmpty) {
      evolutionEvents.add(
        ArchiveDeepDiveTimelineEvent(
          label: 'Strongest month',
          subtitle:
              '${beliefTimeline.peakLabel} · ${beliefTimeline.peakPercent}% overlap',
        ),
      );
    }

    ArchiveDeepDiveTimelineEvent? mostRecent;
    if (latest != null) {
      mostRecent = ArchiveDeepDiveTimelineEvent(
        label: 'Most recent evidence',
        subtitle: _quote(latest.transcript),
        entryId: latest.id,
        at: latest.createdAt,
      );
    }

    return ArchiveDeepDiveBeliefTimeline(
      firstMention: firstMention,
      keyRecordings: keyRecordings,
      evolutionEvents: evolutionEvents.take(6).toList(),
      mostRecent: mostRecent,
    );
  }

  ArchiveDeepDiveExcerpt _excerptFrom(JournalEntry e) {
    return ArchiveDeepDiveExcerpt(
      entryId: e.id,
      dateLabel: formatUserFacingDate(e.createdAt),
      quote: _quote(e.transcript),
    );
  }

  JournalEntry? _entryNearDate(List<JournalEntry> entries, DateTime? target) {
    if (entries.isEmpty || target == null) return entries.firstOrNull;
    JournalEntry? best;
    var bestDelta = Duration(days: 99999);
    for (final e in entries) {
      final d = e.createdAt.difference(target).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = e;
      }
    }
    return best;
  }

  String _quote(String transcript) {
    final t = transcript.trim();
    if (t.length <= 160) return t;
    return '${t.substring(0, 160).trim()}…';
  }
}

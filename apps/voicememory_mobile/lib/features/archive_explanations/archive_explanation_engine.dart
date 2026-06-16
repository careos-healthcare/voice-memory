import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../contradiction_detection/contradiction_report.dart';
import '../discover/belief_engine.dart';
import '../discover/chapter_engine.dart';
import '../discover/discover_engine.dart';
import '../discover/discover_models.dart';
import '../discover/theme_engine.dart';
import '../weekly_story/weekly_story_engine.dart';
import 'belief_timeline_engine.dart';
import 'cross_reference_engine.dart';
import 'explanation_models.dart';

/// Builds evidence-backed explanations, surprises, and challenges.
class ArchiveExplanationEngine {
  const ArchiveExplanationEngine({
    this.beliefTimelineEngine = const BeliefTimelineEngine(),
    this.crossReferenceEngine = const CrossReferenceEngine(),
    this.discoverEngine = const DiscoverYourselfEngine(),
  });

  final BeliefTimelineEngine beliefTimelineEngine;
  final CrossReferenceEngine crossReferenceEngine;
  final DiscoverYourselfEngine discoverEngine;

  static const int minEvidenceForSurprise = 5;

  ArchiveExplanation? buildExplanation({
    required ArchiveInsightRef ref,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    String? askPromptAnswer,
    List<String>? askCitedIds,
  }) {
    if (entries.isEmpty) return null;

    final snapshot = discoverEngine.build(
      entries: entries,
      state: state,
      useCache: true,
    );

    return switch (ref.kind) {
      ArchiveInsightKind.belief => _beliefExplanation(entries, state, snapshot),
      ArchiveInsightKind.beliefChange => _beliefChangeExplanation(
        ref.index ?? 0,
        entries,
        state,
        snapshot,
      ),
      ArchiveInsightKind.theme => _themeExplanation(
        ref.themeKey ?? '',
        entries,
        state,
        snapshot,
      ),
      ArchiveInsightKind.contradiction => _contradictionExplanation(
        ref.entryIdA ?? '',
        ref.entryIdB ?? '',
        entries,
        state,
      ),
      ArchiveInsightKind.blindSpot => _blindSpotExplanation(
        ref.blindSpotId ?? '',
        entries,
        state,
        snapshot,
      ),
      ArchiveInsightKind.chapter => _chapterExplanation(
        ref.chapterId ?? '',
        entries,
      ),
      ArchiveInsightKind.weeklyStory => _weeklyStoryExplanation(entries, state),
      ArchiveInsightKind.askArchive => _askExplanation(
        ref.id,
        entries,
        state,
        askCitedIds ?? const [],
        resolvedPrompt: askPromptAnswer ?? ref.askPrompt,
      ),
      ArchiveInsightKind.surprise => _surpriseExplanation(
        ref.surpriseIndex ?? 0,
        entries,
        state,
      ),
      ArchiveInsightKind.challenge => _challengeExplanation(
        ref.challengeIndex ?? 0,
        entries,
        state,
      ),
    };
  }

  List<UnexpectedObservation> buildUnexpectedInsights(
    List<JournalEntry> entries,
  ) {
    if (archiveEvidenceReflectionCount(entries) < minEvidenceForSurprise) {
      return const [];
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final observations = <UnexpectedObservation>[];

    _relationshipVsWorkMismatch(eligible, observations);
    _confidentSelfVsUncertainLanguage(eligible, observations);
    _timeBlameVsDecisions(eligible, observations);

    observations.sort((a, b) => b.confidence.compareTo(a.confidence));
    return observations.take(5).toList();
  }

  List<ChallengeInsight> buildChallengeInsights(List<JournalEntry> entries) {
    if (archiveEvidenceReflectionCount(entries) < minEvidenceForSurprise) {
      return const [];
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final challenges = <ChallengeInsight>[];

    _attentionVsRecognition(eligible, challenges);
    _workStressVsRelationships(eligible, challenges);

    challenges.sort((a, b) => b.confidence.compareTo(a.confidence));
    return challenges.take(4).toList();
  }

  List<ArchiveNoticedItem> buildNoticedFeed({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    final items = <ArchiveNoticedItem>[];
    final surprises = buildUnexpectedInsights(entries);
    final challenges = buildChallengeInsights(entries);

    for (var i = 0; i < surprises.length; i++) {
      final o = surprises[i];
      items.add(
        ArchiveNoticedItem(
          ref: ArchiveInsightRef.surprise(i),
          headline: 'Unexpected observation',
          preview: o.body,
          isChallenge: false,
          isGold: true,
        ),
      );
    }

    for (var i = 0; i < challenges.length; i++) {
      final c = challenges[i];
      items.add(
        ArchiveNoticedItem(
          ref: ArchiveInsightRef.challenge(i),
          headline: c.headline,
          preview: c.body,
          isChallenge: true,
          isGold: true,
        ),
      );
    }

    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: state?.belief,
    );
    if (contradictions.reports.isNotEmpty) {
      final top = contradictions.reports.first;
      items.add(
        ArchiveNoticedItem(
          ref: ArchiveInsightRef.contradiction(
            entryIdA: top.originalEntryId,
            entryIdB: top.conflictingEntryId,
          ),
          headline: 'Contradiction in your archive',
          preview:
              'Two reflections pull in different directions about the same theme.',
          isChallenge: false,
          isGold: false,
        ),
      );
    }

    final themes = DiscoverThemeEngine().build(entries: entries);
    if (themes.isNotEmpty && themes.first.trend == ThemeTrendDirection.up) {
      items.add(
        ArchiveNoticedItem(
          ref: ArchiveInsightRef.theme(themes.first.themeKey),
          headline: 'Emerging theme: ${themes.first.name}',
          preview:
              '${themes.first.name} appears ${themes.first.frequency} times and is trending up.',
          isChallenge: false,
          isGold: false,
        ),
      );
    }

    return items.take(3).toList();
  }

  ArchiveExplanation? _beliefExplanation(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DiscoverYourselfSnapshot snapshot,
  ) {
    final card =
        snapshot.belief ??
        const DiscoverBeliefEngine().build(entries: entries, state: state);
    if (card == null) return null;

    final belief = card.statement;
    final supporting = _refsFromEntries(card.supportingEntries);
    final contradicting = _contradictingForBelief(entries, belief, supporting);
    final cross = crossReferenceEngine.build(
      entries: entries,
      state: state,
      focusBelief: belief,
      focusEntryIds: supporting.map((e) => e.entryId).toList(),
    );
    final timeline = beliefTimelineEngine.build(
      entries: entries,
      beliefText: belief,
    );

    return ArchiveExplanation(
      insightId: 'belief',
      kind: ArchiveInsightKind.belief,
      title: 'Current belief',
      beliefStatement: belief,
      explanation: _whyBeliefBody(belief, card.evidenceCount),
      whySummary:
          state?.evidenceSummary ??
          'This belief is inferred from recurring language in your recordings.',
      supportingEvidence: supporting,
      contradictingEvidence: contradicting,
      relatedThemes: cross.relatedThemes,
      relatedBeliefs: cross.relatedBeliefs,
      relatedBlindSpots: cross.relatedBlindSpots,
      relatedContradictions: cross.relatedContradictions,
      timeline: timeline,
      confidence: card.confidencePercent.toDouble(),
      hasDeeperContent: card.evidenceCount > 3,
    );
  }

  ArchiveExplanation? _beliefChangeExplanation(
    int index,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DiscoverYourselfSnapshot snapshot,
  ) {
    if (index >= snapshot.beliefChanges.length) return null;
    final change = snapshot.beliefChanges[index];
    final byId = {for (final e in entries) e.id: e};
    final supportEntries = [
      for (final id in change.evidenceEntryIds)
        if (byId[id] != null) byId[id]!,
    ];
    final supporting = _refsFromEntries(supportEntries);

    return ArchiveExplanation(
      insightId: 'belief-change:$index',
      kind: ArchiveInsightKind.beliefChange,
      title: 'Belief change',
      beliefStatement: change.beliefStatement,
      explanation: change.headline,
      whySummary:
          '${change.priorLabel}: ${change.priorPercent}% → '
          '${change.currentLabel}: ${change.currentPercent}%. '
          '${change.evidenceEntryIds.length} reflections support this shift.',
      supportingEvidence: supporting,
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(
            entries: entries,
            state: state,
            focusBelief: change.beliefStatement,
          )
          .relatedThemes,
      relatedBeliefs: [
        if (change.before != null)
          RelatedBelief(statement: change.before!, relevanceScore: 70),
        RelatedBelief(statement: change.beliefStatement, relevanceScore: 90),
      ],
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: beliefTimelineEngine.build(
        entries: entries,
        beliefText: change.beliefStatement,
      ),
      confidence: change.confidence.toDouble(),
      hasDeeperContent: supporting.length > 2,
    );
  }

  ArchiveExplanation? _themeExplanation(
    String themeKey,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DiscoverYourselfSnapshot snapshot,
  ) {
    DiscoverThemeInsight? theme;
    for (final t in snapshot.themes) {
      if (t.themeKey == themeKey) {
        theme = t;
        break;
      }
    }
    if (theme == null) return null;

    final byId = {for (final e in entries) e.id: e};
    final supportEntries = [
      for (final id in theme.evidenceEntryIds)
        if (byId[id] != null) byId[id]!,
    ];
    final supporting = _refsFromEntries(supportEntries);

    return ArchiveExplanation(
      insightId: 'theme:$themeKey',
      kind: ArchiveInsightKind.theme,
      title: theme.name,
      explanation:
          '“${theme.name}” shows up in ${theme.frequency} reflections. '
          'The archive treats recurring themes as signals of what your mind returns to.',
      whySummary: 'Theme frequency and transcript overlap drive this insight.',
      supportingEvidence: supporting,
      contradictingEvidence: const [],
      relatedThemes: [
        RelatedTheme(
          name: theme.name,
          themeKey: theme.themeKey,
          frequency: theme.frequency,
          relevanceScore: 90,
        ),
        ...crossReferenceEngine
            .build(entries: entries, state: state, focusThemeKeys: [themeKey])
            .relatedThemes
            .where((t) => t.themeKey != themeKey),
      ],
      relatedBeliefs: crossReferenceEngine
          .build(entries: entries, state: state, focusThemeKeys: [themeKey])
          .relatedBeliefs,
      relatedBlindSpots: crossReferenceEngine
          .build(entries: entries, state: state, focusThemeKeys: [themeKey])
          .relatedBlindSpots,
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: (theme.frequency * 12).clamp(40, 88).toDouble(),
      hasDeeperContent: supporting.length > 2,
    );
  }

  ArchiveExplanation? _contradictionExplanation(
    String entryIdA,
    String entryIdB,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: state?.belief,
    );
    ContradictionReport? report;
    for (final r in result.reports) {
      if ((r.originalEntryId == entryIdA && r.conflictingEntryId == entryIdB) ||
          (r.originalEntryId == entryIdB && r.conflictingEntryId == entryIdA)) {
        report = r;
        break;
      }
    }
    if (report != null) {
      return _contradictionFromReport(report, entries);
    }

    final byId = {for (final e in entries) e.id: e};
    final a = byId[entryIdA];
    final b = byId[entryIdB];
    if (a == null || b == null) return null;

    final supporting = [_refFromEntry(a), _refFromEntry(b)];
    return ArchiveExplanation(
      insightId: 'contradiction:$entryIdA|$entryIdB',
      kind: ArchiveInsightKind.contradiction,
      title: 'Contradiction',
      explanation:
          'These two recordings sit in tension — the archive links them as a possible contradiction.',
      whySummary:
          'You opened a paired contrast between reflections recorded on different days.',
      supportingEvidence: supporting,
      contradictingEvidence: supporting,
      relatedThemes: crossReferenceEngine
          .build(
            entries: entries,
            state: state,
            focusEntryIds: [entryIdA, entryIdB],
          )
          .relatedThemes,
      relatedBeliefs: const [],
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: 60,
      hasDeeperContent: true,
    );
  }

  ArchiveExplanation _contradictionFromReport(
    ContradictionReport report,
    List<JournalEntry> entries,
  ) {
    final byId = {for (final e in entries) e.id: e};
    final supporting = <EvidenceReference>[];
    if (byId[report.originalEntryId] != null) {
      supporting.add(_refFromEntry(byId[report.originalEntryId]!));
    }
    if (byId[report.conflictingEntryId] != null) {
      supporting.add(_refFromEntry(byId[report.conflictingEntryId]!));
    }

    return ArchiveExplanation(
      insightId:
          'contradiction:${report.originalEntryId}|${report.conflictingEntryId}',
      kind: ArchiveInsightKind.contradiction,
      title: 'Contradiction',
      explanation:
          'The archive detected opposing statements that may reflect competing needs.',
      whySummary: 'Shared themes or language patterns link these two lines.',
      supportingEvidence: supporting,
      contradictingEvidence: supporting,
      relatedThemes: const [],
      relatedBeliefs: const [],
      relatedBlindSpots: const [],
      relatedContradictions: [
        RelatedContradiction(
          id: report.id,
          summary:
              '“${report.originalStatement}” vs “${report.conflictingStatement}”',
          relevanceScore: report.confidenceScore,
        ),
      ],
      timeline: BeliefTimeline.empty,
      confidence: report.confidenceScore.toDouble(),
      hasDeeperContent: true,
    );
  }

  ArchiveExplanation? _blindSpotExplanation(
    String spotId,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DiscoverYourselfSnapshot snapshot,
  ) {
    DiscoverBlindSpotCard? spot;
    for (final s in snapshot.blindSpots) {
      if (s.id == spotId) {
        spot = s;
        break;
      }
    }
    if (spot == null) return null;

    final byId = {for (final e in entries) e.id: e};
    final supportEntries = [
      for (final id in spot.entryIds)
        if (byId[id] != null) byId[id]!,
    ];

    return ArchiveExplanation(
      insightId: 'blindspot:$spotId',
      kind: ArchiveInsightKind.blindSpot,
      title: 'Blind spot',
      explanation: spot.observation,
      whySummary: spot.headline,
      supportingEvidence: _refsFromEntries(supportEntries),
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(entries: entries, state: state, focusEntryIds: spot.entryIds)
          .relatedThemes,
      relatedBeliefs: const [],
      relatedBlindSpots: [
        RelatedBlindSpot(
          id: spot.id,
          headline: spot.headline,
          relevanceScore: spot.confidence,
        ),
      ],
      relatedContradictions: crossReferenceEngine
          .build(entries: entries, state: state, focusEntryIds: spot.entryIds)
          .relatedContradictions,
      timeline: BeliefTimeline.empty,
      confidence: spot.confidence.toDouble(),
      hasDeeperContent: spot.evidenceCount > 2,
    );
  }

  ArchiveExplanation? _chapterExplanation(
    String chapterId,
    List<JournalEntry> entries,
  ) {
    final chapters = const DiscoverChapterEngine().build(entries);
    DiscoverChapterSummary? chapter;
    for (final c in chapters) {
      if (c.id == chapterId) {
        chapter = c;
        break;
      }
    }
    if (chapter == null) return null;

    final byId = {for (final e in entries) e.id: e};
    final supportEntries = [
      for (final id in chapter.entryIds)
        if (byId[id] != null) byId[id]!,
    ];

    return ArchiveExplanation(
      insightId: 'chapter:$chapterId',
      kind: ArchiveInsightKind.chapter,
      title: chapter.title,
      explanation: chapter.summary,
      whySummary:
          '${chapter.entryCount} entries cluster in this period (${chapter.startDate.toLocal().year}).',
      supportingEvidence: _refsFromEntries(supportEntries),
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(entries: entries, focusEntryIds: chapter.entryIds)
          .relatedThemes,
      relatedBeliefs: const [],
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: 72,
      hasDeeperContent: chapter.entryCount > 3,
    );
  }

  ArchiveExplanation? _weeklyStoryExplanation(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final story = const WeeklyStoryEngine().build(
      entries: entries,
      state: state,
    );
    if (story == null) return null;

    return ArchiveExplanation(
      insightId: 'weekly-story',
      kind: ArchiveInsightKind.weeklyStory,
      title: 'Your week in reflection',
      explanation:
          '${story.reflectionCountThisWeek} reflections this week; '
          'themes and beliefs summarized from real counts only.',
      whySummary: story.primaryBelief != null
          ? 'Central belief: “${story.primaryBelief}”'
          : 'Weekly theme frequencies from your archive.',
      supportingEvidence: const [],
      contradictingEvidence: const [],
      relatedThemes: story.topThemes
          .map(
            (t) => RelatedTheme(
              name: t.label,
              themeKey: t.label.toLowerCase(),
              frequency: t.count,
              relevanceScore: 70,
            ),
          )
          .toList(),
      relatedBeliefs: story.primaryBelief != null
          ? [RelatedBelief(statement: story.primaryBelief!, relevanceScore: 80)]
          : const [],
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: 68,
      hasDeeperContent: true,
    );
  }

  ArchiveExplanation? _askExplanation(
    String promptOrId,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    List<String> citedIds, {
    String? resolvedPrompt,
  }) {
    final prompt =
        resolvedPrompt ??
        (promptOrId.startsWith('ask:') ? null : promptOrId) ??
        'What changed most?';
    final answer = discoverEngine.answerArchiveQuestion(
      prompt: prompt,
      entries: entries,
      state: state,
    );
    if (answer == null) return null;

    final byId = {for (final e in entries) e.id: e};
    final supporting = [
      for (final id in answer.citedEntryIds)
        if (byId[id] != null) _refFromEntry(byId[id]!),
    ];

    return ArchiveExplanation(
      insightId: 'ask:${prompt.hashCode}',
      kind: ArchiveInsightKind.askArchive,
      title: prompt,
      explanation: answer.answerLines.join('\n'),
      whySummary: 'Answer assembled from cited archive entries only.',
      supportingEvidence: supporting,
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedThemes,
      relatedBeliefs: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedBeliefs,
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: supporting.isEmpty ? 40 : 72,
      hasDeeperContent: supporting.length > 1,
    );
  }

  ArchiveExplanation? _surpriseExplanation(
    int index,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final list = buildUnexpectedInsights(entries);
    if (index >= list.length) return null;
    final o = list[index];
    final byId = {for (final e in entries) e.id: e};
    return ArchiveExplanation(
      insightId: 'surprise:$index',
      kind: ArchiveInsightKind.surprise,
      title: 'Unexpected observation',
      explanation: o.body,
      whySummary: o.headline,
      supportingEvidence: [
        for (final id in o.evidenceEntryIds)
          if (byId[id] != null) _refFromEntry(byId[id]!),
      ],
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedThemes,
      relatedBeliefs: const [],
      relatedBlindSpots: const [],
      relatedContradictions: const [],
      timeline: BeliefTimeline.empty,
      confidence: o.confidence.toDouble(),
      hasDeeperContent: true,
    );
  }

  ArchiveExplanation? _challengeExplanation(
    int index,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final list = buildChallengeInsights(entries);
    if (index >= list.length) return null;
    final c = list[index];
    final byId = {for (final e in entries) e.id: e};
    return ArchiveExplanation(
      insightId: 'challenge:$index',
      kind: ArchiveInsightKind.challenge,
      title: c.headline,
      explanation: c.body,
      whySummary:
          'The archive compares how you describe yourself with what you record.',
      supportingEvidence: [
        for (final id in c.evidenceEntryIds)
          if (byId[id] != null) _refFromEntry(byId[id]!),
      ],
      contradictingEvidence: const [],
      relatedThemes: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedThemes,
      relatedBeliefs: const [],
      relatedBlindSpots: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedBlindSpots,
      relatedContradictions: crossReferenceEngine
          .build(entries: entries, state: state)
          .relatedContradictions,
      timeline: BeliefTimeline.empty,
      confidence: c.confidence.toDouble(),
      hasDeeperContent: true,
    );
  }

  String _whyBeliefBody(String belief, int evidenceCount) {
    return 'The archive weighs $evidenceCount reflections where your language '
        'repeatedly supports: “$belief”.';
  }

  List<EvidenceReference> _refsFromEntries(List<JournalEntry> entries) {
    return entries.map(_refFromEntry).toList();
  }

  EvidenceReference _refFromEntry(JournalEntry e) {
    final t = e.transcript.trim();
    final excerpt = t.length > 140 ? '${t.substring(0, 140)}…' : t;
    return EvidenceReference(
      entryId: e.id,
      recordedAt: e.createdAt,
      excerpt: excerpt.isEmpty ? e.reflection.concreteObservation : excerpt,
    );
  }

  List<EvidenceReference> _contradictingForBelief(
    List<JournalEntry> entries,
    String belief,
    List<EvidenceReference> supporting,
  ) {
    final supportIds = supporting.map((e) => e.entryId).toSet();
    final eligible = archiveEligibleEvidenceEntries(entries);
    final contradicting = <EvidenceReference>[];

    for (final e in eligible) {
      if (supportIds.contains(e.id)) continue;
      final t = e.transcript.toLowerCase();
      if (t.contains('independent') ||
          t.contains('on my own') ||
          t.contains('without approval') ||
          t.contains('decided without')) {
        contradicting.add(_refFromEntry(e));
      }
    }
    return contradicting.take(6).toList();
  }

  void _relationshipVsWorkMismatch(
    List<JournalEntry> eligible,
    List<UnexpectedObservation> out,
  ) {
    var rel = 0;
    var workConcern = 0;
    final relIds = <String>[];
    final workIds = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      if (t.contains('relationship') ||
          t.contains('partner') ||
          t.contains('family')) {
        rel++;
        if (relIds.length < 4) relIds.add(e.id);
      }
      if (t.contains('work') || t.contains('job') || t.contains('career')) {
        workIds.add(e.id);
        if (t.contains('stress') ||
            t.contains('worry') ||
            t.contains('anxious')) {
          workConcern++;
        }
      }
    }

    if (rel >= 4 && workConcern >= 2 && rel > workConcern) {
      out.add(
        UnexpectedObservation(
          headline: 'Unexpected observation',
          body:
              'You mention relationships ${rel}x in eligible reflections, '
              'while work stress language appears in $workConcern recordings — '
              'even when work is often stated as a primary concern.',
          evidenceEntryIds: [...relIds, ...workIds].toSet().take(4).toList(),
          confidence: 68,
        ),
      );
    }
  }

  void _confidentSelfVsUncertainLanguage(
    List<JournalEntry> eligible,
    List<UnexpectedObservation> out,
  ) {
    var confidentSelf = 0;
    var uncertain = 0;
    final ids = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      if (t.contains('confident') || t.contains('sure of myself')) {
        confidentSelf++;
      }
      if (t.contains('uncertain') ||
          t.contains("don't know") ||
          t.contains('unsure') ||
          t.contains('not sure')) {
        uncertain++;
        if (ids.length < 5) ids.add(e.id);
      }
    }

    if (confidentSelf >= 2 && uncertain >= 3) {
      final pct = ((uncertain / eligible.length) * 100).round();
      out.add(
        UnexpectedObservation(
          headline: 'Unexpected observation',
          body:
              'You sometimes describe yourself as confident, yet uncertainty '
              'language appears in about $pct% of eligible entries.',
          evidenceEntryIds: ids,
          confidence: 72,
        ),
      );
    }
  }

  void _timeBlameVsDecisions(
    List<JournalEntry> eligible,
    List<UnexpectedObservation> out,
  ) {
    var timeBlame = 0;
    var decision = 0;
    final ids = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      if (t.contains('no time') ||
          t.contains('not enough time') ||
          t.contains('too busy')) {
        timeBlame++;
      }
      if (t.contains('decide') ||
          t.contains('decision') ||
          t.contains('choice') ||
          t.contains('stuck choosing')) {
        decision++;
        if (ids.length < 4) ids.add(e.id);
      }
    }

    if (timeBlame >= 3 && decision >= 3) {
      out.add(
        UnexpectedObservation(
          headline: 'Unexpected observation',
          body:
              'You repeatedly mention time pressure ($timeBlame times), '
              'but frustration recordings often reference decisions ($decision times), '
              'not lack of time alone.',
          evidenceEntryIds: ids,
          confidence: 65,
        ),
      );
    }
  }

  void _attentionVsRecognition(
    List<JournalEntry> eligible,
    List<ChallengeInsight> out,
  ) {
    var dislikeAttention = 0;
    var wantRecognition = 0;
    final ids = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      if (t.contains('hate attention') ||
          t.contains('dislike attention') ||
          t.contains("don't like the spotlight")) {
        dislikeAttention++;
      }
      if (t.contains('recognition') ||
          t.contains('noticed') ||
          t.contains('want credit') ||
          t.contains('appreciated')) {
        wantRecognition++;
        if (ids.length < 4) ids.add(e.id);
      }
    }

    if (dislikeAttention >= 1 && wantRecognition >= 2) {
      out.add(
        ChallengeInsight(
          headline: 'Your archive may disagree',
          body:
              'You often describe disliking attention, yet several recordings '
              'reference wanting recognition or appreciation.',
          evidenceEntryIds: ids,
          confidence: 70,
        ),
      );
    }
  }

  void _workStressVsRelationships(
    List<JournalEntry> eligible,
    List<ChallengeInsight> out,
  ) {
    var workStress = 0;
    var relDifficult = 0;
    final ids = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      final difficult =
          t.contains('difficult') ||
          t.contains('hurt') ||
          t.contains('conflict') ||
          t.contains('argument');
      if ((t.contains('work') || t.contains('job')) &&
          (t.contains('stress') || difficult)) {
        workStress++;
      }
      if ((t.contains('relationship') ||
              t.contains('family') ||
              t.contains('partner')) &&
          difficult) {
        relDifficult++;
        if (ids.length < 4) ids.add(e.id);
      }
    }

    if (workStress >= 2 && relDifficult >= 3 && relDifficult > workStress) {
      out.add(
        ChallengeInsight(
          headline: 'Your archive may disagree',
          body:
              'You describe work as a main source of stress, but difficult '
              'recordings mention relationships more often ($relDifficult vs $workStress).',
          evidenceEntryIds: ids,
          confidence: 68,
        ),
      );
    }
  }
}

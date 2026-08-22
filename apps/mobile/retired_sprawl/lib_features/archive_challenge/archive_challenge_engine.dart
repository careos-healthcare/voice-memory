import 'package:archiveme_mobile/features/archive_challenge/archive_challenge_models.dart';
import 'package:archiveme_mobile/features/archive_challenge/archive_challenge_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_evidence/evidence_entry_ids.dart';
import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/discover/theme_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Selects one evidence-backed challenge when the archive supports it.
class ArchiveChallengeEngine {
  const ArchiveChallengeEngine({
    this.explanationEngine = const ArchiveExplanationEngine(),
  });

  final ArchiveExplanationEngine explanationEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;
  static const int minEvidenceCount = 2;
  static const int minConfidence = 65;

  /// Loads stored challenge or detects a new one (max one active).
  Future<ArchiveChallenge?> loadActiveChallenge({
    required ArchiveChallengeStore store,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) async {
    if (!ArchiveEvidenceGuard.canSurfaceDiscovery(entries)) {
      await store.writeActive(null);
      return null;
    }

    final dismissedId = await store.readDismissedId();
    final stored = await store.readActive();
    if (stored != null && stored.id == dismissedId) {
      return null;
    }

    if (stored != null && _stillValid(stored, entries)) {
      return stored;
    }

    final detected = detectChallenge(
      entries: entries,
      state: state,
      dismissedId: dismissedId,
    );

    if (detected != null) {
      await store.writeActive(detected);
    } else {
      await store.writeActive(null);
    }
    return detected;
  }

  /// Pure detection — highest-confidence candidate above thresholds.
  ArchiveChallenge? detectChallenge({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    String? dismissedId,
  }) {
    if (!ArchiveEvidenceGuard.canSurfaceDiscovery(entries)) {
      return null;
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final candidates = <ArchiveChallenge>[];

    _detectWorkOverestimation(eligible, candidates);
    _detectConfidenceVsRelationships(eligible, candidates);
    _detectUncertaintyVsFailure(eligible, candidates);
    _mapExplanationChallenges(entries, candidates);

    final fresh = candidates
        .where(
          (c) =>
              c.confidence >= minConfidence &&
              c.evidenceEntryIds.length >= minEvidenceCount &&
              c.id != dismissedId,
        )
        .toList();

    if (fresh.isEmpty) return null;
    fresh.sort((a, b) => b.confidence.compareTo(a.confidence));
    return fresh.first;
  }

  bool _stillValid(ArchiveChallenge challenge, List<JournalEntry> entries) {
    if (challenge.confidence < minConfidence) return false;
    if (challenge.evidenceEntryIds.length < minEvidenceCount) return false;
    final ids = entries.map((e) => e.id).toSet();
    final validEvidence = challenge.evidenceEntryIds.where(ids.contains).length;
    return validEvidence >= minEvidenceCount;
  }

  void _mapExplanationChallenges(
    List<JournalEntry> entries,
    List<ArchiveChallenge> out,
  ) {
    final insights = explanationEngine.buildChallengeInsights(entries);
    for (var i = 0; i < insights.length; i++) {
      final c = insights[i];
      if (c.evidenceEntryIds.length < minEvidenceCount) continue;
      if (c.confidence < minConfidence) continue;
      out.add(
        ArchiveChallenge(
          id: 'archive-challenge:explanation:$i',
          headline: _headlineFromInsight(c),
          body: c.body,
          evidenceEntryIds: c.evidenceEntryIds,
          confidence: c.confidence,
          insightRef: ArchiveInsightRef.challenge(i),
          detectedAt: DateTime.now(),
        ),
      );
    }
  }

  static String _headlineFromInsight(ChallengeInsight c) {
    final body = c.body.trim();
    if (body.length <= 120) return body;
    return '${body.substring(0, 120)}…';
  }

  void _detectWorkOverestimation(
    List<JournalEntry> eligible,
    List<ArchiveChallenge> out,
  ) {
    var workFraming = 0;
    var workMentions = 0;
    final ids = <String>[];

    for (final e in eligible.reversed.take(10)) {
      final t = e.transcript.toLowerCase();
      if (t.contains('work is') &&
          (t.contains('problem') ||
              t.contains('stress') ||
              t.contains('main') ||
              t.contains('biggest'))) {
        workFraming++;
        if (ids.length < 4) ids.add(e.id);
      }
      if (t.contains('work') ||
          t.contains('job') ||
          t.contains('career') ||
          t.contains('office')) {
        workMentions++;
        if (ids.length < 4 && !ids.contains(e.id)) ids.add(e.id);
      }
    }

    final themeCounts = DiscoverLocalThemeCounts.count(eligible);
    final workTheme = themeCounts['work'] ?? themeCounts['career'] ?? 0;
    final relTheme =
        (themeCounts['relationship'] ?? 0) +
        (themeCounts['relationships'] ?? 0);

    if (workFraming < 1) return;
    if (workMentions >= relTheme && workTheme >= relTheme) return;
    if (ids.length < minEvidenceCount) return;

    out.add(
      ArchiveChallenge(
        id: 'archive-challenge:work-overestimate:$workFraming',
        headline: 'You may be overestimating how often work appears.',
        body:
            'You frame work as the main problem in $workFraming recent reflections, '
            'but only $workMentions eligible recordings center on work language '
            '(theme count: $workTheme).',
        evidenceEntryIds: ids.take(4).toList(),
        confidence: 72,
        insightRef: ArchiveInsightRef.askArchive(
          'Why might work appear less often in recordings than I assume?',
        ),
        detectedAt: DateTime.now(),
      ),
    );
  }

  void _detectConfidenceVsRelationships(
    List<JournalEntry> eligible,
    List<ArchiveChallenge> out,
  ) {
    var confidenceProblem = 0;
    final ids = <String>[];

    for (final e in eligible.reversed.take(10)) {
      final t = e.transcript.toLowerCase();
      if ((t.contains('confidence') || t.contains('confident')) &&
          (t.contains('problem') ||
              t.contains('lack') ||
              t.contains('struggle') ||
              t.contains('issue'))) {
        confidenceProblem++;
        if (ids.length < 4) ids.add(e.id);
      }
    }

    if (confidenceProblem < 1) return;

    final themeCounts = DiscoverLocalThemeCounts.count(eligible);
    final conf = (themeCounts['confidence'] ?? 0) + confidenceProblem;
    final rel =
        (themeCounts['relationship'] ?? 0) +
        (themeCounts['relationships'] ?? 0);

    if (rel < minEvidenceCount || rel <= conf) return;
    if (ids.length < minEvidenceCount) {
      for (final e in eligible.reversed) {
        final t = e.transcript.toLowerCase();
        if (t.contains('relationship') ||
            t.contains('partner') ||
            t.contains('family')) {
          if (!ids.contains(e.id)) ids.add(e.id);
        }
        if (ids.length >= minEvidenceCount) break;
      }
    }
    if (ids.length < minEvidenceCount) return;

    out.add(
      ArchiveChallenge(
        id: 'archive-challenge:confidence-vs-rel:$rel',
        headline:
            'You say confidence is the problem.\nRelationships appear more often.',
        body:
            'Reflections naming confidence as a struggle: $confidenceProblem. '
            'Relationship-related theme signal: $rel vs confidence signal: $conf.',
        evidenceEntryIds: ids.take(4).toList(),
        confidence: 70,
        insightRef: ArchiveInsightRef.askArchive(
          'Why do relationships show up more than confidence in my archive?',
        ),
        detectedAt: DateTime.now(),
      ),
    );
  }

  void _detectUncertaintyVsFailure(
    List<JournalEntry> eligible,
    List<ArchiveChallenge> out,
  ) {
    var uncertain = 0;
    var failure = 0;
    final uncertainIds = <String>[];
    final failureIds = <String>[];

    for (final e in eligible) {
      final t = e.transcript.toLowerCase();
      if (t.contains('uncertain') ||
          t.contains("don't know") ||
          t.contains('unsure') ||
          t.contains('not sure')) {
        uncertain++;
        if (uncertainIds.length < 4) uncertainIds.add(e.id);
      }
      if (t.contains('failure') ||
          t.contains('failed') ||
          t.contains('mistake') ||
          t.contains('messed up')) {
        failure++;
        if (failureIds.length < 2) failureIds.add(e.id);
      }
    }

    if (uncertain < minEvidenceCount) return;
    if (uncertain <= failure) return;
    if (failure < 1) return;

    final ids = EvidenceEntryIds.merge([uncertainIds, failureIds]);
    if (ids.length < minEvidenceCount) return;

    out.add(
      ArchiveChallenge(
        id: 'archive-challenge:uncertainty:$uncertain',
        headline: 'You describe uncertainty more than failure.',
        body:
            'Uncertainty language appears in $uncertain eligible recordings; '
            'failure language appears in $failure.',
        evidenceEntryIds: ids,
        confidence: (66 + (uncertain - failure) * 2).clamp(minConfidence, 85),
        insightRef: ArchiveInsightRef.askArchive(
          'Why does uncertainty language outweigh failure language in my recordings?',
        ),
        detectedAt: DateTime.now(),
      ),
    );
  }
}
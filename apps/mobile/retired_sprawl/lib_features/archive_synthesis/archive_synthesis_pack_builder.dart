import 'package:archiveme_mobile/core/config/theory_tracking_feature_flags.dart';
import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_hash.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';

/// Builds deterministic input pack from Archive V1 engines (no LLM).
abstract class ArchiveSynthesisPackBuilder {
  ArchiveSynthesisPackBuilder._();

  static const int packVersion = 2;
  static const int maxReflectionIndex = 80;
  static const int maxExcerptChars = 280;

  static Map<String, dynamic> build({
    required ArchiveV1View view,
    required String monthKey,
    required Set<int> milestonesReached,
  }) {
    final eligible = archiveEligibleEvidenceEntries(view.eligibleEntries);
    final theory = view.theory;
    final belief = view.belief;

    final ranking = view.theoryRanking;
    final theoryTrackingOn = TheoryTrackingFeatureFlags.enableTheoryTracking;
    final pack = <String, dynamic>{
      'packVersion': packVersion,
      'monthKey': monthKey,
      'eligibleCount': eligible.length,
      'primaryBelief': _beliefRef(belief),
      if (theoryTrackingOn) ...{
        'primaryTheory': _theoryRef(
          ranking?.primaryTheory ?? _theoryAsRanked(theory),
        ),
        'secondaryTheories': (ranking?.secondaryTheories ?? const [])
            .map(_theoryRef)
            .whereType<Map<String, dynamic>>()
            .toList(),
        'theory': theory == null
            ? null
            : {
                'statement': theory.statement,
                'confidencePercent': theory.confidencePercent,
                'evidenceCount': theory.evidenceCount,
                'counterEvidenceCount': theory.counterEvidenceCount,
              },
      },
      'lifecycle': _lifecycleJson(view.lifecycle),
      'changeFeed': _changeFeedJson(view.changeFeed),
      'contradictions': view.contradictions
          .map(
            (c) => {
              'id': c.id,
              'youSay': c.youSay,
              'but': c.but,
              'confidenceScore': c.confidenceScore,
              'entryIds': c.entryIds,
            },
          )
          .toList(),
      'blindSpots': view.blindSpots
          .map(
            (b) => {
              'id': b.id,
              'headline': b.headline,
              'observation': b.observation,
              'entryIds': b.entryIds,
            },
          )
          .toList(),
      'surprises': view.surprises.observations
          .map(
            (s) => {
              'id': s.id,
              'observation': s.observation,
              'evidenceEntryIds': s.evidenceEntryIds,
              'confidenceScore': s.confidenceScore,
            },
          )
          .toList(),
      'evidenceTrails': _evidenceTrails(belief, eligible, view),
      'reflectionIndex': _reflectionIndex(eligible),
      'milestonesReached': milestonesReached.toList()..sort(),
    };

    return pack;
  }

  static Map<String, dynamic> buildWithDeepDiveContext({
    required ArchiveV1View view,
    required String monthKey,
    required Set<int> milestonesReached,
    required ArchiveDeepDiveView dive,
  }) {
    final pack = build(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestonesReached,
    );
    pack['deepDiveContext'] = _deepDiveContext(dive);
    return pack;
  }

  static Map<String, dynamic>? _beliefRef(ArchiveV1Belief? belief) {
    if (belief == null) return null;
    return {
      'statement': belief.statement,
      'confidencePercent': belief.confidencePercent,
      'evidenceCount': belief.evidenceCount,
    };
  }

  static Map<String, dynamic>? _theoryRef(RankedTheory? t) {
    if (t == null) return null;
    return {
      'candidateId': t.candidateId,
      'statement': t.statement,
      'confidencePercent': t.confidencePercent,
      'evidenceCount': t.evidenceCount,
      'counterEvidenceCount': t.counterEvidenceCount,
      'rankScore': t.rankScore,
    };
  }

  static RankedTheory? _theoryAsRanked(ArchiveCurrentTheory? theory) {
    if (theory == null) return null;
    return RankedTheory(
      candidateId: 'hero-theory',
      statement: theory.statement,
      source: 'theory',
      confidencePercent: theory.confidencePercent,
      evidenceCount: theory.evidenceCount,
      counterEvidenceCount: theory.counterEvidenceCount,
      rankScore: 0,
      supportingEntries: const [],
      supportingEvidence: const [],
      lastUpdated: theory.lastUpdated,
    );
  }

  static Map<String, dynamic> _deepDiveContext(ArchiveDeepDiveView dive) {
    final excerptIds = <String>{
      ...dive.why.excerptLines.map((e) => e.entryId),
      ...dive.counterEvidence.forExcerpts.map((e) => e.entryId),
      ...dive.counterEvidence.againstExcerpts.map((e) => e.entryId),
    }.toList();
    final labels = <String>[
      if (dive.history.firstAppearance.label.isNotEmpty)
        dive.history.firstAppearance.label,
      if (dive.history.strongestAppearance.label.isNotEmpty)
        dive.history.strongestAppearance.label,
      if (dive.history.latestAppearance.label.isNotEmpty)
        dive.history.latestAppearance.label,
      ...dive.timeline.firstMention?.label != null
          ? [dive.timeline.firstMention!.label]
          : [],
      ...dive.timeline.mostRecent?.label != null
          ? [dive.timeline.mostRecent!.label]
          : [],
    ];
    return {
      'beliefStatement': dive.beliefStatement,
      'confidencePercent': dive.confidencePercent,
      'whySummaryLines': dive.why.summaryLines,
      'excerptEntryIds': excerptIds,
      'timelineLabels': labels,
    };
  }

  static String hashForView({
    required ArchiveV1View view,
    required String monthKey,
    required Set<int> milestonesReached,
  }) {
    final pack = build(
      view: view,
      monthKey: monthKey,
      milestonesReached: milestonesReached,
    );
    return computeArchiveHashFromPack(pack);
  }

  static Map<String, dynamic> _lifecycleJson(BeliefLifecycleView lifecycle) {
    final current = lifecycle.current;
    return {
      'current': current == null
          ? null
          : {
              'statement': current.statement,
              'status': current.status.name,
              if (current.firstSeen != null)
                'firstSeen': current.firstSeen!.toUtc().toIso8601String(),
              if (current.lastSeen != null)
                'lastSeen': current.lastSeen!.toUtc().toIso8601String(),
            },
      'retired': lifecycle.retired
          .map(
            (r) => {
              'statement': r.statement,
              'status': r.status.name,
              if (r.lastSeen != null)
                'lastSeen': r.lastSeen!.toUtc().toIso8601String(),
            },
          )
          .toList(),
    };
  }

  static Map<String, dynamic> _changeFeedJson(ArchiveChangeFeedView feed) {
    return {
      'hasBaseline': feed.hasBaseline,
      if (feed.reviewedAt != null)
        'reviewedAt': feed.reviewedAt!.toUtc().toIso8601String(),
      'newReflectionCount': feed.newReflectionCount,
      'beliefsStrengthened': feed.beliefsStrengthened
          .map(
            (b) => {
              'statement': b.statement,
              'confidenceBefore': b.confidenceBefore,
              'confidenceNow': b.confidenceNow,
            },
          )
          .toList(),
      'beliefsWeakened': feed.beliefsWeakened
          .map(
            (b) => {
              'statement': b.statement,
              'confidenceBefore': b.confidenceBefore,
              'confidenceNow': b.confidenceNow,
            },
          )
          .toList(),
      'contradictionsAppeared': feed.contradictionsAppeared
          .map((c) => {'youSay': c.youSay, 'but': c.but})
          .toList(),
      'contradictionsResolved': feed.contradictionsResolved
          .map((c) => {'youSay': c.youSay, 'but': c.but})
          .toList(),
      'themesIncreasing': feed.themesIncreasing
          .map((t) => {'label': t.label, 'mentionsNow': t.mentionsNow})
          .toList(),
      'themesDecreasing': feed.themesDecreasing
          .map((t) => {'label': t.label, 'mentionsNow': t.mentionsNow})
          .toList(),
    };
  }

  static Map<String, dynamic> _evidenceTrails(
    ArchiveV1Belief? belief,
    List<JournalEntry> eligible,
    ArchiveV1View view,
  ) {
    final supporting = belief?.supportingEntries ?? const [];
    final supportIds = supporting.map((e) => e.id).toSet();
    final forExcerpts = supporting.take(5).map(_excerpt).toList();

    final against = <Map<String, String>>[];
    for (final c in view.contradictions) {
      for (final id in c.entryIds.take(2)) {
        final entry = _entryById(eligible, id);
        if (entry != null && !supportIds.contains(entry.id)) {
          against.add(_excerpt(entry));
        }
      }
    }
    if (against.length < 3) {
      for (final e in eligible) {
        if (supportIds.contains(e.id)) continue;
        against.add(_excerpt(e));
        if (against.length >= 5) break;
      }
    }

    return {
      'forExcerpts': forExcerpts,
      'againstExcerpts': against.take(5).toList(),
    };
  }

  static Map<String, String> _excerpt(JournalEntry entry) {
    final text = UserContentSafety.redactSecrets(entry.transcript.trim());
    final quote = UserContentSafety.safeSnippet(
      text,
      maxChars: maxExcerptChars,
    );
    return {'entryId': entry.id, 'quote': quote};
  }

  static List<Map<String, dynamic>> _reflectionIndex(
    List<JournalEntry> eligible,
  ) {
    final sorted = [...eligible]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(maxReflectionIndex).map(_reflectionRow).toList();
  }

  static Map<String, dynamic> _reflectionRow(JournalEntry entry) {
    final r = entry.reflection;
    return {
      'id': entry.id,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'mood': r.mood,
      'emotionalIntensity': r.emotionalIntensity,
      'recurringThemes': r.recurringThemes,
      'concreteObservation': _truncate(
        UserContentSafety.redactSecrets(r.concreteObservation),
        400,
      ),
      'repeatedSignal': _truncate(
        UserContentSafety.redactSecrets(r.repeatedSignal),
        200,
      ),
      if (r.tensionOrContradiction != null &&
          r.tensionOrContradiction!.isNotEmpty)
        'tensionOrContradiction': _truncate(
          UserContentSafety.redactSecrets(r.tensionOrContradiction!),
          200,
        ),
    };
  }

  static JournalEntry? _entryById(List<JournalEntry> entries, String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  static String _truncate(String text, int max) {
    final t = UserContentSafety.sanitizePlainText(text);
    if (t.length <= max) return t;
    return UserContentSafety.safeSnippet(t, maxChars: max);
  }
}
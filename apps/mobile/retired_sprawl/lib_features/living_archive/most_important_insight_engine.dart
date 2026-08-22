import 'package:archiveme_mobile/design/warm_archive_copy.dart';
import 'package:archiveme_mobile/features/archive_challenge/archive_challenge_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_detector.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_models.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_copy.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_models.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Picks exactly one hero insight when the archive opens.
class MostImportantInsightEngine {
  const MostImportantInsightEngine({
    this.beliefChangeDetector = const BeliefChangeDetector(),
  });

  final BeliefChangeDetector beliefChangeDetector;

  MostImportantInsight? pick({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    ArchiveWasWrongInsight? wasWrong,
    DailyDiscovery? dailyDiscovery,
    ArchiveChallenge? challenge,
    ReturnReasonCard? returnReason,
  }) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) return null;

    final candidates = <MostImportantInsight>[];

    if (wasWrong != null) {
      candidates.add(_fromWasWrong(wasWrong));
    }

    _confidenceChange(entries, state, snapshotBaseline, candidates);
    if (dailyDiscovery != null) {
      candidates.add(_fromDaily(dailyDiscovery));
    }
    if (challenge != null) {
      candidates.add(_fromChallenge(challenge));
    }
    _beliefChanges(entries, state, candidates);
    if (returnReason != null) {
      candidates.add(_fromReturnReason(returnReason));
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final p = a.priority.index.compareTo(b.priority.index);
      if (p != 0) return p;
      return b.confidence.compareTo(a.confidence);
    });
    return candidates.first;
  }

  void _confidenceChange(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? baseline,
    List<MostImportantInsight> out,
  ) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return;

    const timelineEngine = BeliefTimelineEngine();
    final timeline = timelineEngine.build(entries: entries, beliefText: belief);
    if (timeline.points.length < 2) return;

    final prior = baseline?.confidence ?? timeline.points.first.strengthPercent;
    final current = timeline.currentPercent;
    final delta = current - prior;
    if (delta.abs() < LivingArchiveCopy.minConfidenceChangePercent) return;

    final evidence = archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();
    if (evidence.length < 2) return;

    final headline = WarmArchiveCopy.confidenceShiftPhrase(
      prior: prior,
      current: current,
    );
    final summary = belief.length > 72 ? '${belief.substring(0, 72)}…' : belief;

    out.add(
      MostImportantInsight(
        headline: headline,
        summary: summary,
        why:
            'Based on how often this story shows up in your eligible recordings.',
        confidence: (65 + delta.abs()).toDouble(),
        evidenceIds: evidence,
        openedRoute: '/archive-explanation/${Uri.encodeComponent('belief')}',
        priority: MostImportantInsightPriority.confidenceChanged,
        createdAt: DateTime.now(),
        insightRef: ArchiveInsightRef.belief(),
      ),
    );
  }

  void _beliefChanges(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    List<MostImportantInsight> out,
  ) {
    final alerts = beliefChangeDetector.detect(entries: entries, state: state);
    if (alerts.isEmpty) return;
    final top = alerts.first;
    if (top.evidenceEntryIds.length < 2) return;

    final ref = ArchiveInsightRef.beliefChange(0);
    final headline = switch (top.type) {
      BeliefChangeAlertType.confidenceDecrease ||
      BeliefChangeAlertType.disappearingBelief => 'This belief is weakening.',
      BeliefChangeAlertType.confidenceIncrease =>
        'This belief is strengthening.',
      BeliefChangeAlertType.newBeliefEmerging =>
        'Your archive noticed something.',
    };

    out.add(
      MostImportantInsight(
        headline: headline,
        summary: top.beliefStatement,
        why: WarmArchiveCopy.beliefChangeNarrative(
          priorLabel: top.priorLabel,
          priorPercent: top.priorPercent,
          currentLabel: top.currentLabel,
          currentPercent: top.currentPercent,
        ),
        confidence: (60 + top.magnitude).toDouble(),
        evidenceIds: top.evidenceEntryIds,
        openedRoute: '/archive-explanation/${Uri.encodeComponent(ref.id)}',
        priority: MostImportantInsightPriority.beliefChange,
        createdAt: DateTime.now(),
        insightRef: ref,
      ),
    );
  }

  static MostImportantInsight _fromWasWrong(ArchiveWasWrongInsight w) {
    return MostImportantInsight(
      headline: w.headline,
      summary: w.summary.replaceAll('\n', ' ').trim(),
      why:
          'Recent recordings outweigh what the archive assumed from earlier evidence.',
      confidence: w.confidence.toDouble(),
      evidenceIds: w.evidenceIds,
      openedRoute:
          '/archive-explanation/${Uri.encodeComponent(w.insightRef.id)}',
      priority: MostImportantInsightPriority.archiveWasWrong,
      createdAt: DateTime.now(),
      insightRef: w.insightRef,
      isArchiveWasWrong: true,
    );
  }

  static MostImportantInsight _fromDaily(DailyDiscovery d) {
    return MostImportantInsight(
      headline: LivingArchiveCopy.curiosityHeadlineForDailyType(d.type),
      summary: d.summary,
      why: d.whyItMatters,
      confidence: d.confidence,
      evidenceIds: d.evidenceIds,
      openedRoute:
          '/archive-explanation/${Uri.encodeComponent(d.insightRef.id)}',
      priority: MostImportantInsightPriority.dailyDiscovery,
      createdAt: d.createdAt,
      insightRef: d.insightRef,
    );
  }

  static MostImportantInsight _fromChallenge(ArchiveChallenge challenge) {
    return MostImportantInsight(
      headline: challenge.headline,
      summary: challenge.headline,
      why: challenge.body,
      confidence: challenge.confidence.toDouble(),
      evidenceIds: challenge.evidenceEntryIds,
      openedRoute:
          '/archive-explanation/${Uri.encodeComponent(challenge.insightRef.id)}',
      priority: MostImportantInsightPriority.challenge,
      createdAt: DateTime.now(),
      insightRef: challenge.insightRef,
      askPrompt: challenge.insightRef.askPrompt,
    );
  }

  static MostImportantInsight _fromReturnReason(ReturnReasonCard card) {
    return MostImportantInsight(
      headline: 'Your archive is still uncertain.',
      summary: card.bodyLines.join(' '),
      why:
          card.state.primaryMessage ??
          'More recordings may resolve open patterns.',
      confidence: 62,
      evidenceIds: const [],
      openedRoute: '/archive-explanation/${Uri.encodeComponent('belief')}',
      priority: MostImportantInsightPriority.returnReason,
      createdAt: DateTime.now(),
      insightRef: ArchiveInsightRef.belief(),
    );
  }
}
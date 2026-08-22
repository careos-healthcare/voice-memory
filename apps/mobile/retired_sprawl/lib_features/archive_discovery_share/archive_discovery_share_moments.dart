import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_card_model.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_types.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_models.dart';

/// In-context share cards from existing archive data — no new AI.
abstract class ArchiveDiscoveryShareMoments {
  ArchiveDiscoveryShareMoments._();

  static ArchiveDiscoveryShareCardModel? fromContradiction(
    ArchiveV1Contradiction contradiction,
  ) {
    final you = contradiction.youSay.trim();
    final but = contradiction.but.trim();
    if (you.isEmpty || but.isEmpty) return null;
    final count = contradiction.entryIds.length;
    return ArchiveDiscoveryShareCardModel(
      id: 'contradiction-${contradiction.id}',
      type: ArchiveDiscoveryShareCardType.contradiction,
      insight: '${_clip(you, 72)} — but recordings also show ${_clip(but, 72)}',
      evidenceRecordingCount: count > 0 ? count : 1,
    );
  }

  static ArchiveDiscoveryShareCardModel? fromThenNow(ArchiveV1ThenNow thenNow) {
    if (!thenNow.hasDistinctEvolution) return null;
    final then = thenNow.thenBelief.trim();
    final now = thenNow.nowBelief.trim();
    if (then.isEmpty || now.isEmpty) return null;
    return ArchiveDiscoveryShareCardModel(
      id: 'belief-evolution',
      type: ArchiveDiscoveryShareCardType.beliefChange,
      insight:
          'I used to believe ${_clip(then, 80)}. Now my archive shows ${_clip(now, 80)}.',
      evidenceRecordingCount: thenNow.supportingEvidenceCount,
    );
  }

  static ArchiveDiscoveryShareCardModel? fromBeliefWeakened(
    ArchiveChangeBeliefRow row,
  ) {
    final statement = row.statement.trim();
    if (statement.isEmpty) return null;
    return ArchiveDiscoveryShareCardModel(
      id: 'belief-weakened-${statement.hashCode}',
      type: ArchiveDiscoveryShareCardType.beliefChange,
      insight: 'A belief is fading: ${_clip(statement, 120)}',
      evidenceRecordingCount: row.evidenceCount,
    );
  }

  static ArchiveDiscoveryShareCardModel? fromChangeContradiction(
    ArchiveChangeContradictionRow row,
  ) {
    final you = row.youSay.trim();
    final but = row.but.trim();
    if (you.isEmpty || but.isEmpty) return null;
    return ArchiveDiscoveryShareCardModel(
      id: 'change-contradiction-${you.hashCode}',
      type: ArchiveDiscoveryShareCardType.contradiction,
      insight: '${_clip(you, 72)} — but recordings also show ${_clip(but, 72)}',
      evidenceRecordingCount: row.evidenceCount,
    );
  }

  static bool isLifecycleShareable(BeliefLifecycleEntry entry) {
    if (entry.isNoLongerDetected) return true;
    if (entry.status == BeliefLifecycleStatus.weakening) return true;
    return entry.events.any(
      (e) =>
          e.phase == BeliefLifecyclePhase.weakening ||
          e.phase == BeliefLifecyclePhase.death,
    );
  }

  static ArchiveDiscoveryShareCardModel? fromLifecycleEntry(
    BeliefLifecycleEntry entry,
  ) {
    if (!isLifecycleShareable(entry)) return null;

    final latestEvent = entry.events.isNotEmpty ? entry.events.last : null;
    final statement = entry.statement.trim();
    if (statement.isEmpty && latestEvent == null) return null;

    final insight = latestEvent != null && latestEvent.summary.trim().isNotEmpty
        ? _clip(latestEvent.summary, 160)
        : entry.isNoLongerDetected
        ? 'A belief is no longer showing up in recent recordings: ${_clip(statement, 100)}'
        : 'Belief lifecycle update (${BeliefLifecycleCopy.statusLabelFor(entry.status)}): ${_clip(statement, 100)}';

    return ArchiveDiscoveryShareCardModel(
      id: 'lifecycle-${statement.hashCode}',
      type: ArchiveDiscoveryShareCardType.beliefLifecycle,
      insight: insight,
      evidenceRecordingCount: _lifecycleEvidenceCount(entry),
    );
  }

  static ArchiveDiscoveryShareCardModel? fromSurprise(
    ArchiveSurpriseObservation observation,
  ) {
    final text = observation.observation.trim();
    if (text.isEmpty) return null;
    return ArchiveDiscoveryShareCardModel(
      id: 'surprise-${observation.id}',
      type: ArchiveDiscoveryShareCardType.surpriseObservation,
      insight: _clip(text, 160),
      evidenceRecordingCount: observation.evidenceCount,
    );
  }

  static ArchiveDiscoveryShareCardModel? fromMonthlyConclusion({
    required ArchiveSynthesisConclusion conclusion,
    required ArchiveMonthlyReview review,
  }) {
    final statement = conclusion.statement.trim();
    if (statement.isEmpty) return null;
    final evidenceCount = conclusion.evidence.isNotEmpty
        ? conclusion.evidence.length
        : review.eligibleCount;
    return ArchiveDiscoveryShareCardModel(
      id: 'monthly-${conclusion.id}',
      type: ArchiveDiscoveryShareCardType.monthlyReviewInsight,
      insight: _clip(statement, 160),
      evidenceRecordingCount: evidenceCount,
    );
  }

  static int _lifecycleEvidenceCount(BeliefLifecycleEntry entry) {
    if (entry.events.isNotEmpty) return entry.events.length.clamp(1, 999);
    return 1;
  }

  static String _clip(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}
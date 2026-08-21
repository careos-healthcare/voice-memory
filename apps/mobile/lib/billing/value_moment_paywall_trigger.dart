import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/features/pressure_retention/archive_proof_counter_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:flutter/foundation.dart';

/// The small Pro bridge shown after a value moment: a calm continuation of
/// evidence the user just saw, never a full-screen interruption.
class ValueMomentBridge {
  const ValueMomentBridge({
    required this.show,
    this.body = fallbackBody,
    this.cardType = '',
  });

  factory ValueMomentBridge.none() => const ValueMomentBridge(show: false);

  static const String title = 'Keep the longer proof trail';
  static const String ctaLabel = 'See Pro';
  static const String dismissLabel = 'Not now';

  // Body variants — one per value moment, each only used when the
  // underlying evidence is genuinely true. Fixed copy only: never user
  // snippets, belief phrases, or source terms.
  static const String threadReturnBody =
      'This thread has returned before. Pro keeps the evidence history so '
      'ArchiveMe can show whether it gets stronger, softer, or changes.';
  static const String beliefBody =
      'A belief-like phrase showed up again. Pro keeps the timeline of what '
      'changed across your archive.';
  static const String weeklyBody =
      'Your weekly review found something to compare. Pro keeps weekly archive '
      'reviews so ArchiveMe can track what changed over time.';
  static const String proofCounterBody =
      'Your archive has connected recordings. Pro keeps the full evidence '
      'history as the trail grows.';
  static const String fallbackBody =
      'Your first repeat is free. Pro keeps the evidence history so ArchiveMe '
      'can show whether patterns get stronger, softer, or change over time.';

  final bool show;

  /// The body for the most specific true value moment in this archive.
  final String body;

  /// Stable id of the value moment behind this bridge — safe for analytics
  /// (`thread_return`, `belief_distance`, `archive_proof_counter`,
  /// `weekly_thread_review`). Never user text.
  final String cardType;
}

/// Decides when the Pro bridge may appear. Pure evaluation over the same
/// engines that power the value cards — the bridge can never claim a value
/// moment the user has not actually been shown evidence for.
///
/// Value moments (any one is enough):
/// - Thread Return Evidence exists (a thread connects 2+ entries)
/// - A belief-like phrase repeated
/// - A weekly thread review exists
/// - The proof counter holds 2+ connected recordings
///
/// Never shown: to Pro users, before the first saved entry, before any value
/// moment, or again in the same session after a dismissal.
class ValueMomentPaywallTrigger {
  const ValueMomentPaywallTrigger();

  static const _threadEngine = ThreadReturnEvidenceEngine();
  static const _beliefEngine = BeliefDistanceEngine();
  static const _counterEngine = ArchiveProofCounterEngine();
  static const _weeklyEngine = WeeklyThreadReviewEngine();

  /// One dismissal hides the bridge for the rest of the app session.
  static bool dismissedThisSession = false;

  @visibleForTesting
  static void resetSessionForTest() {
    dismissedThisSession = false;
  }

  /// [now] is injectable for tests and forwarded to the engines.
  ValueMomentBridge build(
    List<PressureCheckInRecord> records, {
    required bool isPro,
    DateTime? now,
  }) {
    if (isPro || dismissedThisSession || records.isEmpty) {
      return ValueMomentBridge.none();
    }
    final evidenceMilestoneCount = MagicMomentsCounter.countFromPressureRecords(
      records,
      now: now,
    );
    if (evidenceMilestoneCount < MagicMomentsCounter.paywallThreshold ||
        !DelayedPaywallProofStore.hasSeenFirstRepeat ||
        !DelayedPaywallProofStore.hasOpenedEvidenceTrail) {
      return ValueMomentBridge.none();
    }
    // Memory off: every value moment here is a memory-based connection
    // claim, so the bridge never shows — the paywall cannot claim
    // continuity value the archive is not currently providing.
    if (!MemoryScopePolicy.memoryClaimsAllowed) {
      return ValueMomentBridge.none();
    }

    final evidence = _threadEngine.build(records, now: now);
    final belief = _beliefEngine.build(records);
    final counter = _counterEngine.build(records, now: now);
    final review = _weeklyEngine.build(records, now: now);

    // Most specific true value moment first. "Returned before" needs a
    // thread with 3+ appearances; a 2-entry thread stays at the cautious
    // connected-recordings body.
    if (evidence.hasEvidence && evidence.occurrenceCount >= 3) {
      return const ValueMomentBridge(
        show: true,
        body: ValueMomentBridge.threadReturnBody,
        cardType: 'thread_return',
      );
    }
    if (belief.hasBelief) {
      return const ValueMomentBridge(
        show: true,
        body: ValueMomentBridge.beliefBody,
        cardType: 'belief_distance',
      );
    }
    if (counter.connectedCount >= 2) {
      return const ValueMomentBridge(
        show: true,
        body: ValueMomentBridge.proofCounterBody,
        cardType: 'archive_proof_counter',
      );
    }
    if (review.hasReview) {
      return const ValueMomentBridge(
        show: true,
        body: ValueMomentBridge.weeklyBody,
        cardType: 'weekly_thread_review',
      );
    }
    return ValueMomentBridge.none();
  }
}
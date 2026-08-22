import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Persists proof milestones required before Pro bridge or paywall may show.
abstract final class DelayedPaywallProofStore {
  DelayedPaywallProofStore._();

  static const prefsKey = 'delayedPaywallProof_v1';

  /// Minimum distinct evidence milestones before Pro surfaces may appear.
  static const minEvidenceMilestonesForPaywall =
      MagicMomentsCounter.paywallThreshold;

  /// @deprecated Prefer [minEvidenceMilestonesForPaywall].
  static const minMagicMomentsForPaywall = minEvidenceMilestonesForPaywall;

  /// @deprecated Raw entry count is not a paywall gate — use
  /// [minEvidenceMilestonesForPaywall] with [resolveEvidenceMilestoneCount].
  static const minSavedMoments = minEvidenceMilestonesForPaywall;

  static bool _loaded = false;
  static bool _hasSeenFirstRepeat = false;
  static bool _hasOpenedEvidenceTrail = false;

  /// Widget tests bypass the gate unless a file opts out explicitly.
  static bool get isGateBypassedForTesting => bypassGateForTest;

  @visibleForTesting
  static bool bypassGateForTest = false;

  static bool get hasSeenFirstRepeat => _hasSeenFirstRepeat;
  static bool get hasOpenedEvidenceTrail => _hasOpenedEvidenceTrail;

  /// Proof-first gate: ≥3 evidence milestones, first repeat seen, evidence
  /// trail opened.
  static bool passesGateFor({int? evidenceMilestoneCount, int? magicMomentsCount}) =>
      bypassGateForTest ||
      (resolveEvidenceMilestoneCount(
                evidenceMilestoneCount ?? magicMomentsCount,
              ) >=
              minEvidenceMilestonesForPaywall &&
          _hasSeenFirstRepeat &&
          _hasOpenedEvidenceTrail);

  static bool get passesGate => passesGateFor();

  static int resolveEvidenceMilestoneCount([int? override]) {
    if (override != null) return override;
    if (!AppServices.isInitialized) return 0;
    final entries = peekJournalEntriesSync(AppServices.instance.journalStore);
    return MagicMomentsCounter.countFromJournalEntries(entries);
  }

  /// @deprecated Prefer [resolveEvidenceMilestoneCount].
  static int resolveMagicMomentsCount([int? override]) =>
      resolveEvidenceMilestoneCount(override);

  /// Beta feedback only — not used for paywall eligibility.
  static int resolveSavedMomentCount() {
    if (!AppServices.isInitialized) return 0;
    return MagicMomentsCounter.countSavedMoments(
      peekJournalEntriesSync(AppServices.instance.journalStore),
    );
  }

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    _hasSeenFirstRepeat = raw?['hasSeenFirstRepeat'] == true;
    _hasOpenedEvidenceTrail = raw?['hasOpenedEvidenceTrail'] == true;
    _loaded = true;
  }

  static Future<void> markFirstRepeatSeen() async {
    if (_hasSeenFirstRepeat) return;
    _hasSeenFirstRepeat = true;
    _loaded = true;
    await _persist();
  }

  static Future<void> markEvidenceTrailOpened() async {
    if (_hasOpenedEvidenceTrail) return;
    _hasOpenedEvidenceTrail = true;
    _loaded = true;
    await _persist();
  }

  /// Seeds proof milestones for App Store review demo — unlocks paywall + Pro bridge.
  static Future<void> seedReviewerMilestones({MobilePrefsStore? prefs}) async {
    _hasSeenFirstRepeat = true;
    _hasOpenedEvidenceTrail = true;
    _loaded = true;
    if (AppServices.isInitialized) {
      await _persist();
      return;
    }
    if (prefs != null) {
      await prefs.writeMap(prefsKey, {
        'hasSeenFirstRepeat': true,
        'hasOpenedEvidenceTrail': true,
      });
    }
  }

  static Future<void> _persist() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {
      'hasSeenFirstRepeat': _hasSeenFirstRepeat,
      'hasOpenedEvidenceTrail': _hasOpenedEvidenceTrail,
    });
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _loaded = false;
    _hasSeenFirstRepeat = false;
    _hasOpenedEvidenceTrail = false;
    bypassGateForTest = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest({
    bool hasSeenFirstRepeat = false,
    bool hasOpenedEvidenceTrail = false,
  }) {
    _loaded = true;
    _hasSeenFirstRepeat = hasSeenFirstRepeat;
    _hasOpenedEvidenceTrail = hasOpenedEvidenceTrail;
  }
}
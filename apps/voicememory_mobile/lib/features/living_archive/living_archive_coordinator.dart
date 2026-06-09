import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_challenge/archive_challenge_engine.dart';
import '../archive_challenge/archive_challenge_store.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../archive_state_object/archive_state_object.dart';
import '../daily_discoveries/daily_discovery_engine.dart';
import '../daily_discoveries/daily_discovery_store.dart';
import '../archive_evolution/archive_evolution_coordinator.dart';
import '../archive_evolution/archive_evolution_store.dart';
import 'archive_was_wrong_engine.dart';
import 'belief_under_review_engine.dart';
import 'discovery_streak_engine.dart';
import 'discovery_streak_store.dart';
import 'living_archive_models.dart';
import 'most_important_insight_engine.dart';
import 'what_changed_today_engine.dart';

/// Builds the Living Archive v1 view model for Archive home.
class LivingArchiveCoordinator {
  const LivingArchiveCoordinator({
    this.wasWrongEngine = const ArchiveWasWrongEngine(),
    this.mostImportantEngine = const MostImportantInsightEngine(),
    this.beliefReviewEngine = const BeliefUnderReviewEngine(),
    this.whatChangedEngine = const WhatChangedTodayEngine(),
    this.streakEngine = const DiscoveryStreakEngine(),
    this.dailyEngine = const DailyDiscoveryEngine(),
    this.challengeEngine = const ArchiveChallengeEngine(),
  });

  final ArchiveWasWrongEngine wasWrongEngine;
  final MostImportantInsightEngine mostImportantEngine;
  final BeliefUnderReviewEngine beliefReviewEngine;
  final WhatChangedTodayEngine whatChangedEngine;
  final DiscoveryStreakEngine streakEngine;
  final DailyDiscoveryEngine dailyEngine;
  final ArchiveChallengeEngine challengeEngine;

  Future<LivingArchiveView> build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    MobilePrefsStore? prefs,
  }) async {
    final store = prefs ?? AppServices.instance.prefs;
    final discoveryStore = DailyDiscoveryStore(store);
    final discoveryBaseline = await discoveryStore.readBaseline();

    final wasWrong = wasWrongEngine.detect(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      discoveryBaseline: discoveryBaseline,
    );

    final daily = await dailyEngine.loadTodayDiscovery(
      store: discoveryStore,
      entries: entries,
      state: state,
    );

    final challenge = await challengeEngine.loadActiveChallenge(
      store: ArchiveChallengeStore(store),
      entries: entries,
      state: state,
    );

    final evolution = await const ArchiveEvolutionCoordinator().resolveForArchive(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      prefs: store,
    );

    final evolutionState = await ArchiveEvolutionStore(store).read();
    final lastEntryAt = entries.isNotEmpty
        ? entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;
    final lastArchiveUpdateAt =
        evolutionState.lastArchiveUpdateAt ?? lastEntryAt;

    final mostImportant = evolution == null
        ? mostImportantEngine.pick(
            entries: entries,
            state: state,
            snapshotBaseline: snapshotBaseline,
            discoveryBaseline: discoveryBaseline,
            wasWrong: wasWrong,
            dailyDiscovery: daily,
            challenge: challenge,
            returnReason: null,
          )
        : null;

    final whatChangedToday = whatChangedEngine.build(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      discoveryBaseline: discoveryBaseline,
    );

    final streakDays = await DiscoveryStreakStore(store).readDiscoveryDays();
    final streak = streakEngine.compute(streakDays);

    if (evolution != null || mostImportant != null) {
      await _recordStreakForInsight(store);
    }

    final hasMore = (whatChangedToday?.hasContent ?? false) ||
        mostImportant != null ||
        (daily != null && evolution == null) ||
        (challenge != null && evolution == null);

    return LivingArchiveView(
      mostImportant: mostImportant,
      archiveWasWrong: wasWrong,
      beliefUnderReview: null,
      whatChangedToday: whatChangedToday,
      discoveryStreak: streak,
      hasMoreDiscoveries: hasMore,
      evolution: evolution,
      lastArchiveUpdateAt: lastArchiveUpdateAt,
    );
  }

  static Future<void> _recordStreakForInsight(
    MobilePrefsStore prefs,
  ) async {
    final store = DiscoveryStreakStore(prefs);
    await store.recordDiscoveryDay(DateTime.now());
  }

  /// Call when daily discovery, challenge, or wrong-card surfaces.
  static Future<void> recordDiscoverySurfaced(MobilePrefsStore prefs) async {
    await DiscoveryStreakStore(prefs).recordDiscoveryDay(DateTime.now());
  }
}

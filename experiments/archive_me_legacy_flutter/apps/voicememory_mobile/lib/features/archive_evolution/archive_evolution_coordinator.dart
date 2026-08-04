import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../archive_state_object/archive_state_object.dart';
import '../daily_discoveries/daily_discovery_store.dart';
import 'archive_evolution_analytics.dart';
import 'archive_evolution_engine.dart';
import 'archive_evolution_models.dart';
import 'archive_evolution_store.dart';

class ArchiveEvolutionCoordinator {
  const ArchiveEvolutionCoordinator({
    this.engine = const ArchiveEvolutionEngine(),
  });

  final ArchiveEvolutionEngine engine;

  Future<ArchiveEvolution?> resolveForArchive({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    MobilePrefsStore? prefs,
  }) async {
    return _resolve(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      prefs: prefs ?? AppServices.instance.prefs,
      afterRecording: false,
    );
  }

  Future<ArchiveEvolution?> detectAfterRecording({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    MobilePrefsStore? prefs,
  }) async {
    final p = prefs ?? AppServices.instance.prefs;
    final evolution = await _resolve(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      prefs: p,
      afterRecording: true,
    );
    if (evolution != null) {
      await ArchiveEvolutionStore(p).setPendingEvolutionEvent(evolution);
    }
    return evolution;
  }

  Future<ArchiveEvolution?> _resolve({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    required MobilePrefsStore prefs,
    required bool afterRecording,
  }) async {
    final store = ArchiveEvolutionStore(prefs);
    final engagement = await store.read();
    final lastEntryId = entries.isNotEmpty ? entries.last.id : '';

    final discoveryStore = DailyDiscoveryStore(prefs);
    final discoveryBaseline = await discoveryStore.readBaseline();
    final viewed = await discoveryStore.readViewedIds();

    final detected = afterRecording
        ? engine.detectAfterNewRecording(
            entries: entries,
            state: state,
            snapshotBaseline: snapshotBaseline,
            discoveryBaseline: discoveryBaseline,
            viewedDiscoveryIds: viewed,
          )
        : engine.detect(
            entries: entries,
            state: state,
            snapshotBaseline: snapshotBaseline,
            discoveryBaseline: discoveryBaseline,
            viewedDiscoveryIds: viewed,
          );

    final lastActivity = entries.isNotEmpty
        ? entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
        : engagement.lastArchiveUpdateAt;

    if (detected == null) {
      if (lastActivity != null) {
        await store.touchArchiveUpdate();
      }
      return null;
    }

    if (engagement.lastDismissedEvolutionId == detected.id &&
        engagement.lastEntryIdWhenEvolved == lastEntryId) {
      return null;
    }

    final active = engagement.activeEvolution;
    if (active != null &&
        active.id == detected.id &&
        engagement.lastEntryIdWhenEvolved == lastEntryId) {
      await ArchiveEvolutionAnalytics.seen(active);
      return active;
    }

    await store.writeActiveEvolution(
      evolution: detected,
      lastEntryId: lastEntryId,
    );
    await ArchiveEvolutionAnalytics.seen(detected);
    return detected;
  }

  Future<void> markOpened(
    ArchiveEvolution evolution, {
    MobilePrefsStore? prefs,
  }) async {
    await ArchiveEvolutionAnalytics.opened(evolution);
    await ArchiveEvolutionAnalytics.completed(evolution);
  }

  Future<void> markIgnored(
    ArchiveEvolution evolution, {
    MobilePrefsStore? prefs,
  }) async {
    final store = ArchiveEvolutionStore(prefs ?? AppServices.instance.prefs);
    await store.dismiss(evolution);
    await ArchiveEvolutionAnalytics.ignored(evolution);
  }
}

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../archive_state_object/archive_state_object.dart';
import '../daily_discoveries/daily_discovery_store.dart';
import 'surprise_analytics.dart';
import 'surprise_engine.dart';
import 'surprise_models.dart';
import 'surprise_store.dart';

/// Resolves the single Archive home surprise and persists engagement.
class SurpriseCoordinator {
  const SurpriseCoordinator({
    this.engine = const SurpriseEngine(),
  });

  final SurpriseEngine engine;

  Future<ArchiveSurprise?> resolveForArchive({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    MobilePrefsStore? prefs,
  }) async {
    final p = prefs ?? AppServices.instance.prefs;
    return _resolve(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      prefs: p,
      useImmediateBaseline: false,
    );
  }

  /// Call after each successful recording save.
  Future<ArchiveSurprise?> detectAfterRecording({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    MobilePrefsStore? prefs,
  }) async {
    final p = prefs ?? AppServices.instance.prefs;
    return _resolve(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      prefs: p,
      useImmediateBaseline: true,
    );
  }

  Future<ArchiveSurprise?> _resolve({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    required MobilePrefsStore prefs,
    required bool useImmediateBaseline,
  }) async {
    final store = SurpriseStore(prefs);
    final engagement = await store.read();
    final lastEntryId = entries.isNotEmpty ? entries.last.id : '';

    final discoveryStore = DailyDiscoveryStore(prefs);
    final discoveryBaseline = await discoveryStore.readBaseline();
    final viewed = await discoveryStore.readViewedIds();

    final detected = useImmediateBaseline
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

    if (detected == null) {
      if (engagement.activeSurprise != null) {
        await store.clearActive();
      }
      return null;
    }

    if (engagement.lastDismissedSurpriseId == detected.id &&
        engagement.lastEntryIdWhenSurprised == lastEntryId) {
      return null;
    }

    final active = engagement.activeSurprise;
    if (active != null &&
        active.id == detected.id &&
        engagement.lastEntryIdWhenSurprised == lastEntryId) {
      return active;
    }

    await store.writeActiveSurprise(
      surprise: detected,
      lastEntryId: lastEntryId,
    );
    await SurpriseAnalytics.surfaced(detected);
    return detected;
  }

  Future<void> markOpened(ArchiveSurprise surprise, {MobilePrefsStore? prefs}) async {
    final store = SurpriseStore(prefs ?? AppServices.instance.prefs);
    await store.markSeen(surprise);
    await SurpriseAnalytics.opened(surprise);
  }

  Future<void> markIgnored(ArchiveSurprise surprise, {MobilePrefsStore? prefs}) async {
    final store = SurpriseStore(prefs ?? AppServices.instance.prefs);
    await store.dismiss(surprise);
    await SurpriseAnalytics.ignored(surprise);
  }
}

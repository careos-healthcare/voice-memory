import 'package:archiveme_mobile/features/archive_beliefs/archive_beliefs_presenter.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_engine.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_store.dart';
import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/features/insights/archive_insights_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Generates and persists the return loop after recording; loads it on Patterns.
abstract class TomorrowReturnLoopCoordinator {
  TomorrowReturnLoopCoordinator._();

  static Future<TomorrowReturnLoop?> buildFromEntries(
    List<JournalEntry> entries, {
    DailyDiscovery? immediateDiscovery,
  }) async {
    if (entries.isEmpty) return null;

    final prefs = AppServices.instance.prefs;
    final baselineRaw = await prefs.discoverBaseline;
    final baselineMap = baselineRaw?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final feed = DiscoverLocalEngine.build(
      entries: entries,
      baselineThemes: baselineMap,
    );
    final growth = await ArchiveGrowthService.load();
    final beliefs = ArchiveBeliefsPresenter.build(
      entries: entries,
      archiveV1: growth.archiveV1,
      discoverFeed: feed,
    );
    final insights = const ArchiveInsightsEngine().build(
      entries: entries,
      discoverFeed: feed,
      currentBelief: beliefs.current.isNotEmpty
          ? beliefs.current.first.statement
          : null,
    );

    final loop = const TomorrowReturnLoopEngine().build(
      entries: entries,
      immediateDiscovery: immediateDiscovery,
      discoverFeed: feed,
      beliefs: beliefs,
      insights: insights,
    );
    if (!loop.hasContent) return null;
    return loop;
  }

  static Future<TomorrowReturnLoop?> persistAfterRecording(
    List<JournalEntry> entries, {
    DailyDiscovery? immediateDiscovery,
  }) async {
    final loop = await buildFromEntries(
      entries,
      immediateDiscovery: immediateDiscovery,
    );
    if (loop == null) return null;
    await TomorrowReturnLoopStore(AppServices.instance.prefs).write(loop);
    return loop;
  }

  static Future<TomorrowReturnLoop?> loadForPatterns(
    List<JournalEntry> entries,
  ) async {
    if (entries.isEmpty) return null;

    final store = TomorrowReturnLoopStore(AppServices.instance.prefs);
    final stored = await store.read();
    final now = DateTime.now();
    if (stored != null && stored.isSameCalendarDayAs(now)) {
      return stored;
    }

    DailyDiscovery? discovery;
    try {
      discovery = await const DailyDiscoveryEngine().detectImmediateDiscovery(
        store: DailyDiscoveryStore(AppServices.instance.prefs),
        entries: entries,
      );
    } catch (_, stackTrace) { // ignore: silent_catch_audit — discovery engine best-effort
      discovery = null;
    }

    final loop = await buildFromEntries(entries, immediateDiscovery: discovery);
    if (loop != null) {
      await store.write(loop);
    }
    return loop;
  }
}
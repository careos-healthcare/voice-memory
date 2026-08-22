import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_beliefs_presenter.dart';
import 'package:archiveme_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/archive_changes/archive_changes_eligibility.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Archive-owned loader for the historical Changes presentation.
class ArchiveChangesSnapshot {
  const ArchiveChangesSnapshot({
    required this.entries,
    required this.timeline,
    required this.eligible,
  });

  final List<JournalEntry> entries;
  final List<BeliefChangeTimelineItem> timeline;
  final bool eligible;
}

abstract final class ArchiveChangesAdapter {
  ArchiveChangesAdapter._();

  static Future<ArchiveChangesSnapshot> load() async {
    if (ScreenshotMode.enabled) {
      return ArchiveChangesSnapshot(
        entries: const [],
        timeline: ScreenshotSampleData.changingStories,
        eligible: ScreenshotSampleData.changingStories.isNotEmpty,
      );
    }

    final entries = await AppServices.instance.journal.loadAll();
    await FactLedgerCitationService.warmCache();
    await FactLedgerCitationService.ensureIndexed(entries);
    DiscoverLocalFeed? feed;
    if (!isIntentionalEmptyArchive(entries)) {
      final baseline = await AppServices.instance.prefs.discoverBaseline;
      final baselineMap = baseline?.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      feed = DiscoverLocalEngine.build(
        entries: entries,
        baselineThemes: baselineMap,
      );
    }
    final growth = await ArchiveGrowthService.load();
    final snapshot = ArchiveBeliefsPresenter.build(
      entries: entries,
      archiveV1: growth.archiveV1,
      discoverFeed: feed,
    );
    final timeline = buildBeliefChangeTimeline(snapshot: snapshot, feed: feed);
    return ArchiveChangesSnapshot(
      entries: entries,
      timeline: timeline,
      eligible: ArchiveChangesEligibility.isEligible(
        entries: entries,
        timeline: timeline,
      ),
    );
  }
}

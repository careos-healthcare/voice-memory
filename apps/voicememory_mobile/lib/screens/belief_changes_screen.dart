import 'package:flutter/material.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/empty_archive_experience.dart';
import '../features/archive_beliefs/archive_beliefs_presenter.dart';
import '../features/archive_beliefs/belief_change_timeline.dart';
import '../features/archive_growth/archive_growth_service.dart';
import '../features/discover/discover_local.dart';
import '../models/journal_entry.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/archive_beliefs_dashboard.dart';
import '../widgets/belief_empty_state.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';

/// What is changing — pushed from the Patterns tab.
class BeliefChangesScreen extends StatefulWidget {
  const BeliefChangesScreen({super.key, this.previewTimeline});

  /// Test-only: skip async load and render this timeline.
  @visibleForTesting
  final List<BeliefChangeTimelineItem>? previewTimeline;

  @override
  State<BeliefChangesScreen> createState() => _BeliefChangesScreenState();
}

class _BeliefChangesScreenState extends State<BeliefChangesScreen> {
  List<JournalEntry> _entries = [];
  List<BeliefChangeTimelineItem> _timeline = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewTimeline;
    if (preview != null) {
      _timeline = preview;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _timeline = ScreenshotSampleData.changingStories;
        _loading = false;
      });
      return;
    }
    final entries = await AppServices.instance.journal.loadAll();
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
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _timeline = buildBeliefChangeTimeline(snapshot: snapshot, feed: feed);
      _loading = false;
    });
  }

  bool get _showEmpty {
    if (ScreenshotMode.enabled) return false;
    return isIntentionalEmptyArchive(_entries) || _timeline.isEmpty;
  }

  List<Widget> _pageHeader() {
    return [
      const ConsumerScreenBackHeader(),
      const SizedBox(height: AppSpacing.sm),
      Text(
        ConsumerUiCopy.changesScreenTitle,
        style: VoiceMemoryTypography.headlineStyle(),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        ConsumerUiCopy.changesScreenLead,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontSize: 18),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Padding(
            padding: ArchiveMobileSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConsumerScreenBackHeader(),
                const SizedBox(height: AppSpacing.lg),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    if (_showEmpty && isIntentionalEmptyArchive(_entries)) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ArchiveMobileSpacing.pagePadding,
              children: [
                ..._pageHeader(),
                const BeliefEmptyState(fillViewport: false),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              ..._pageHeader(),
              BeliefChangeStories(items: _timeline),
              if (_timeline.isEmpty) ...[
                Text(
                  ConsumerUiCopy.changesEmptyLead,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

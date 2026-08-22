import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_beliefs_presenter.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_belief_summary_card.dart';
import 'package:archiveme_mobile/widgets/belief_empty_state.dart';
import 'package:archiveme_mobile/widgets/consumer/consumer_screen_back_header.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Beliefs tab — what the archive currently believes and why.
class BeliefsScreen extends StatefulWidget {
  const BeliefsScreen({super.key});

  @override
  State<BeliefsScreen> createState() => _BeliefsScreenState();
}

class _BeliefsScreenState extends State<BeliefsScreen> {
  List<JournalEntry> _entries = [];
  ArchiveBeliefsSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _snapshot = ScreenshotSampleData.beliefsSnapshot;
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
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Widget _backHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConsumerScreenBackHeader(),
        SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ArchiveMobileSpacing.pagePadding.copyWith(bottom: 0),
                child: _backHeader(),
              ),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    if (isIntentionalEmptyArchive(_entries)) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ArchiveMobileSpacing.pagePadding.copyWith(
                      bottom: 0,
                    ),
                    child: _backHeader(),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: BeliefEmptyState(fillViewport: true),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final s = _snapshot!;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              _backHeader(),
              Text(
                ConsumerUiCopy.allPatternsTitle,
                style: VoiceMemoryTypography.headlineStyle(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ConsumerUiCopy.allPatternsLead,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _section(BeliefProductCopy.sectionCurrent, s.current),
              _section(BeliefProductCopy.sectionEmerging, s.emerging),
              _section(BeliefProductCopy.sectionChanging, s.changing),
              _section(BeliefProductCopy.sectionHidden, s.hiddenPatterns),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<ArchiveBeliefCardModel> beliefs) {
    if (beliefs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: VoiceMemoryTypography.sectionTitleStyle()),
          const SizedBox(height: AppSpacing.sm),
          ...beliefs.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ArchiveBeliefSummaryCard(belief: b),
            ),
          ),
        ],
      ),
    );
  }
}
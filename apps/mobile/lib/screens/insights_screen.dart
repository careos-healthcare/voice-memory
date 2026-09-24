import 'package:archiveme_mobile/features/analytics/capture_consistency_heatmap.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/features/ask_archive/ask_archive_entry_bar.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_entry_card.dart';
import 'package:archiveme_mobile/features/insights/trend_pattern_summary_card.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/archive/archive_changes_section.dart';
import 'package:archiveme_mobile/widgets/archive/archive_verified_changes_section.dart';
import 'package:archiveme_mobile/widgets/insight_share/insight_share_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Passive home for pattern synthesis and trend analytics.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(archiveFeedPaginationProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          const Text(
            'Insights',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Patterns and weekly trends stay here so the archive timeline can stay focused on what you captured.',
          ),
          const SizedBox(height: 20),
          const CaptureConsistencyHeatmap(),
          const SizedBox(height: 24),
          const AskArchiveEntryBar(),
          const PatternExplorationEntryCard(),
          const TrendPatternSummaryCard(),
          ArchiveVerifiedChangesSection(
            proofCandidates: feed.verifiedProofEntries,
            proofContextEntries: feed.proofContextEntries,
          ),
          const ArchiveChangesSection(),
          InsightShareExporter(entries: feed.proofContextEntries),
        ],
      ),
    );
  }
}

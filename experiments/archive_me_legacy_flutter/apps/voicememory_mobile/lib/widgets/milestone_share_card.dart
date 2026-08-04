import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/milestone_share/milestone_share_copy.dart';
import '../features/milestone_share/milestone_share_engine.dart';
import '../features/milestone_share/milestone_share_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact milestone share card for Archive Home.
class MilestoneShareHomeCard extends StatefulWidget {
  const MilestoneShareHomeCard({
    super.key,
    required this.entries,
    this.watchlistStore,
    this.engine = const MilestoneShareEngine(),
    this.initialWatchlistCount = 0,
    this.sampleMode = false,
    this.skipPrefsLoad = false,
    this.onPrimaryAction,
  });

  const MilestoneShareHomeCard.test({
    super.key,
    required this.entries,
    this.initialWatchlistCount = 0,
    this.engine = const MilestoneShareEngine(),
    this.onPrimaryAction,
  }) : watchlistStore = null,
       sampleMode = false,
       skipPrefsLoad = true;

  final List<JournalEntry> entries;
  final ArchiveWatchlistStore? watchlistStore;
  final MilestoneShareEngine engine;
  final int initialWatchlistCount;
  final bool sampleMode;
  final bool skipPrefsLoad;
  final VoidCallback? onPrimaryAction;

  @override
  State<MilestoneShareHomeCard> createState() => _MilestoneShareHomeCardState();
}

class _MilestoneShareHomeCardState extends State<MilestoneShareHomeCard> {
  MilestoneShareResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _result = widget.engine.buildFromJournal(
        entries: widget.entries,
        hasWatchTheme: widget.initialWatchlistCount >= 1,
        sampleMode: widget.sampleMode,
      );
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final store =
        widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    final items = await store.loadItems();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: widget.entries,
        hasWatchTheme: items.isNotEmpty,
        sampleMode: widget.sampleMode,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _result == null) {
      return const SizedBox.shrink(key: Key('milestone_share_card_loading'));
    }

    final result = _result!;
    if (ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome ||
        result.isEmpty) {
      return const SizedBox.shrink(key: Key('milestone_share_card_hidden'));
    }

    return Container(
      key: const Key('milestone_share_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MilestoneShareCopy.eyebrow,
            key: const Key('milestone_share_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardHeadline,
            key: const Key('milestone_share_card_headline'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.cardSummary,
            key: const Key('milestone_share_card_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.primaryCard != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.primaryCard!.safeShareText,
              key: const Key('milestone_share_card_share_preview'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('milestone_share_card_primary_button'),
            onPressed:
                widget.onPrimaryAction ??
                () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ],
      ),
    );
  }
}

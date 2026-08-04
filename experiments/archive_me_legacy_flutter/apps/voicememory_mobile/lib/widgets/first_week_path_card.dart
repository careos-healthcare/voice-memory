import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/first_week_path/first_week_path_copy.dart';
import '../features/first_week_path/first_week_path_engine.dart';
import '../features/first_week_path/first_week_path_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact first-week path card for Archive Home — local metadata only.
class FirstWeekPathCard extends StatefulWidget {
  const FirstWeekPathCard({
    super.key,
    required this.entries,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const FirstWeekPathEngine(),
    this.hasWeeklyReviewAvailable = false,
    this.sampleMode = false,
    this._initialResult,
  });

  const FirstWeekPathCard.test({
    super.key,
    required this.entries,
    required FirstWeekPathResult this._initialResult,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const FirstWeekPathEngine(),
    this.hasWeeklyReviewAvailable = false,
    this.sampleMode = false,
  });

  final List<JournalEntry> entries;
  final VoidCallback? onPrimaryAction;
  final ArchiveWatchlistStore? watchlistStore;
  final FirstWeekPathEngine engine;
  final bool hasWeeklyReviewAvailable;
  final bool sampleMode;
  final FirstWeekPathResult? _initialResult;

  @override
  State<FirstWeekPathCard> createState() => _FirstWeekPathCardState();
}

class _FirstWeekPathCardState extends State<FirstWeekPathCard> {
  FirstWeekPathResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.sampleMode || ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = widget.engine.build(
          FirstWeekPathInput(
            realSavedMomentCount: 0,
            hasWatchTheme: false,
            betaFeedbackCaptured: false,
            hasWeeklyReviewAvailable: false,
            sampleMode: true,
          ),
        );
        _loading = false;
      });
      return;
    }

    final watchlist =
        widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    final watchItems = await watchlist.loadItems();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: widget.entries,
        hasWatchTheme: watchItems.isNotEmpty,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
        hasWeeklyReviewAvailable: widget.hasWeeklyReviewAvailable,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('first_week_path_card_loading'));
    }

    final result = _result;
    if (result == null || !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('first_week_path_card_hidden'));
    }

    return Container(
      key: const Key('first_week_path_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.cardTitle,
            key: const Key('first_week_path_card_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.progressLabel,
            key: const Key('first_week_path_progress_label'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardBody,
            key: const Key('first_week_path_card_body'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (result.rewardText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.rewardText,
              key: const Key('first_week_path_reward_text'),
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('first_week_path_primary_button'),
                onPressed:
                    widget.onPrimaryAction ??
                    () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              OutlinedButton(
                key: const Key('first_week_path_view_path_button'),
                onPressed: () => context.push(FirstWeekPathCopy.route),
                child: const Text(FirstWeekPathCopy.viewFullPathCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

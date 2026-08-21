import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_store.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_engine.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Compact daily archive exercise card for Archive Home — local only.
class DailyArchiveExerciseCard extends StatefulWidget {
  const DailyArchiveExerciseCard({
    required this.entries, super.key,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const DailyArchiveExerciseEngine(),
    this.sampleMode = false,
    this._initialResult,
  });

  const DailyArchiveExerciseCard.test({
    required this.entries, required DailyArchiveExerciseResult this._initialResult, super.key,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const DailyArchiveExerciseEngine(),
    this.sampleMode = false,
  });

  final List<JournalEntry> entries;
  final VoidCallback? onPrimaryAction;
  final ArchiveWatchlistStore? watchlistStore;
  final DailyArchiveExerciseEngine engine;
  final bool sampleMode;
  final DailyArchiveExerciseResult? _initialResult;

  @override
  State<DailyArchiveExerciseCard> createState() =>
      _DailyArchiveExerciseCardState();
}

class _DailyArchiveExerciseCardState extends State<DailyArchiveExerciseCard> {
  DailyArchiveExerciseResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.sampleMode || ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = widget.engine.build(
          const DailyArchiveExerciseInput(
            realSavedMomentCount: 0,
            hasWatchTheme: false,
            betaFeedbackCaptured: false,
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
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(
        key: Key('daily_archive_exercise_card_loading'),
      );
    }

    final result = _result;
    if (result == null || !result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('daily_archive_exercise_card_hidden'),
      );
    }

    return Container(
      key: const Key('daily_archive_exercise_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DailyArchiveExerciseCopy.cardLabel,
            key: const Key('daily_archive_exercise_card_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.prompt,
            key: const Key('daily_archive_exercise_card_prompt'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.hint,
            key: const Key('daily_archive_exercise_card_hint'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('daily_archive_exercise_primary_button'),
                onPressed:
                    widget.onPrimaryAction ??
                    () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              OutlinedButton(
                key: const Key('daily_archive_exercise_view_button'),
                onPressed: () => context.push(DailyArchiveExerciseCopy.route),
                child: const Text(DailyArchiveExerciseCopy.viewFullExerciseCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
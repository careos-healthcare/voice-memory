import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_evidence/archive_evidence_guard.dart';
import '../features/demo/sample_archive_mode.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/archive_clarity/archive_clarity_copy.dart';
import '../features/archive_clarity/archive_clarity_engine.dart';
import '../features/archive_clarity/archive_clarity_models.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact archive clarity card for Archive Home — counts only, no journal text.
class ArchiveClarityProgressCard extends StatefulWidget {
  const ArchiveClarityProgressCard({
    super.key,
    required this.entries,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const ArchiveClarityEngine(),
    this.sampleMode = false,
    this.weeklyReviewAvailable = false,
    ArchiveClarityResult? initialResult,
  }) : _initialResult = initialResult;

  const ArchiveClarityProgressCard.test({
    super.key,
    required this.entries,
    required ArchiveClarityResult initialResult,
    this.onPrimaryAction,
    this.watchlistStore,
    this.engine = const ArchiveClarityEngine(),
    this.sampleMode = false,
    this.weeklyReviewAvailable = false,
  }) : _initialResult = initialResult;

  final List<JournalEntry> entries;
  final VoidCallback? onPrimaryAction;
  final ArchiveWatchlistStore? watchlistStore;
  final ArchiveClarityEngine engine;
  final bool sampleMode;
  final bool weeklyReviewAvailable;
  final ArchiveClarityResult? _initialResult;

  @override
  State<ArchiveClarityProgressCard> createState() =>
      _ArchiveClarityProgressCardState();
}

class _ArchiveClarityProgressCardState extends State<ArchiveClarityProgressCard> {
  ArchiveClarityResult? _result;
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
          ArchiveClarityInput(
            realSavedMomentCount: 0,
            usableEvidenceCount: 0,
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
        widget.watchlistStore ?? ArchiveWatchlistStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    final watchItems = await watchlist.loadItems();
    final realEntriesList =
        SampleArchiveMode.excludeSampleEntries(widget.entries);
    final realEntries = realEntriesList.length;
    final usable =
        ArchiveEvidenceGuard.eligibleReflectionCount(realEntriesList);
    if (!mounted) return;
    setState(() {
      _result = widget.engine.build(
        ArchiveClarityInput(
          realSavedMomentCount: realEntries,
          usableEvidenceCount: usable,
          hasWatchTheme: watchItems.isNotEmpty,
          betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
          weeklyReviewAvailable: widget.weeklyReviewAvailable,
        ),
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(
        key: Key('archive_clarity_progress_card_loading'),
      );
    }

    final result = _result;
    if (result == null || !result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('archive_clarity_progress_card_hidden'),
      );
    }

    return Container(
      key: const Key('archive_clarity_progress_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveClarityCopy.cardLabel,
            key: const Key('archive_clarity_progress_card_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.stageLabel,
            key: const Key('archive_clarity_progress_stage'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('archive_clarity_progress_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${ArchiveClarityCopy.evidenceStrengthLabel}: ${result.evidenceStrengthValue}',
            key: const Key('archive_clarity_progress_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('archive_clarity_progress_primary_button'),
                onPressed: widget.onPrimaryAction ??
                    () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              OutlinedButton(
                key: const Key('archive_clarity_progress_view_button'),
                onPressed: () => context.push(ArchiveClarityCopy.route),
                child: const Text(ArchiveClarityCopy.viewClarityCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

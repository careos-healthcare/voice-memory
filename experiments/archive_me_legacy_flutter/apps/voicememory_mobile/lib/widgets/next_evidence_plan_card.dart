import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_models.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/next_evidence_plan/next_evidence_plan_copy.dart';
import '../features/next_evidence_plan/next_evidence_plan_engine.dart';
import '../features/next_evidence_plan/next_evidence_plan_gates.dart';
import '../features/next_evidence_plan/next_evidence_plan_models.dart';
import '../features/return_ritual/return_ritual_copy.dart';
import '../features/return_ritual/return_ritual_models.dart';
import '../features/return_ritual/return_ritual_store.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact next-evidence plan for Archive Home — computed locally, no journal writes.
class NextEvidencePlanCard extends StatefulWidget {
  const NextEvidencePlanCard({
    super.key,
    required this.entryCount,
    required this.entries,
    this.onAddMoment,
    this.onReviewWatchlist,
    this.watchlistStore,
    this.returnRitualStore,
    this.engine = const NextEvidencePlanEngine(),
    this._initialWatchlistItems,
    this._initialReturnRitual,
  });

  const NextEvidencePlanCard.test({
    super.key,
    required this.entryCount,
    required this.entries,
    required this._initialWatchlistItems,
    this._initialReturnRitual,
    this.onAddMoment,
    this.onReviewWatchlist,
    this.watchlistStore,
    this.returnRitualStore,
    this.engine = const NextEvidencePlanEngine(),
  });

  final int entryCount;
  final List<JournalEntry> entries;
  final VoidCallback? onAddMoment;
  final VoidCallback? onReviewWatchlist;
  final ArchiveWatchlistStore? watchlistStore;
  final ReturnRitualStore? returnRitualStore;
  final NextEvidencePlanEngine engine;
  final List<ArchiveWatchlistItem>? _initialWatchlistItems;
  final ReturnRitualChoice? _initialReturnRitual;

  @override
  State<NextEvidencePlanCard> createState() => _NextEvidencePlanCardState();
}

class _NextEvidencePlanCardState extends State<NextEvidencePlanCard> {
  ArchiveWatchlistStore? _watchlistStore;
  ReturnRitualStore? _returnRitualStore;
  List<ArchiveWatchlistItem> _watchlistItems = const [];
  ReturnRitualChoice? _returnRitual;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _watchlistStore = widget.watchlistStore;
    _returnRitualStore = widget.returnRitualStore;
    if (widget._initialWatchlistItems != null ||
        widget._initialReturnRitual != null) {
      _watchlistItems = List<ArchiveWatchlistItem>.from(
        widget._initialWatchlistItems ?? const [],
      );
      _returnRitual = widget._initialReturnRitual;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    _watchlistStore ??= ArchiveWatchlistStore(AppServices.instance.prefs);
    _returnRitualStore ??= ReturnRitualStore(AppServices.instance.prefs);
    final items = await _watchlistStore!.loadItems();
    final ritual = await _returnRitualStore!.load();
    if (!mounted) return;
    setState(() {
      _watchlistItems = items;
      _returnRitual = ritual;
      _loading = false;
    });
  }

  String? get _returnRitualPhrase {
    final choice = _returnRitual;
    if (choice == null || !choice.isValid) return null;
    return choice.resolvePhrase(ReturnRitualCopy.presets);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('next_evidence_plan_card_loading'));
    }

    if (NextEvidencePlanGates.showTeaser(
      entryCount: widget.entryCount,
      sampleMode: false,
    )) {
      final teaser = widget.engine.buildTeaser();
      return _shell(
        key: const Key('next_evidence_plan_teaser'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teaser.title,
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              teaser.body,
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ],
        ),
      );
    }

    if (!NextEvidencePlanGates.showCard(
      entryCount: widget.entryCount,
      sampleMode: false,
    )) {
      return const SizedBox.shrink(key: Key('next_evidence_plan_card_hidden'));
    }

    final result = widget.engine.build(
      entries: widget.entries,
      watchlistItems: _watchlistItems,
      returnRitualPhrase: _returnRitualPhrase,
    );

    return _shell(
      key: const Key('next_evidence_plan_card'),
      child: _planContent(context, result),
    );
  }

  Widget _shell({required Key key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: child,
    );
  }

  Widget _planContent(BuildContext context, NextEvidencePlanResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.title,
          key: const Key('next_evidence_plan_title'),
          style: ArchiveMobileTypography.cardLabel(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.body,
          key: const Key('next_evidence_plan_body'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        if (result.watchlistLine case final line?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            line,
            key: const Key('next_evidence_plan_watchlist_line'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
        if (result.returnRitualLine case final line?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            line,
            key: const Key('next_evidence_plan_return_ritual_line'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
        if (result.secondaryLine case final line?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            line,
            key: const Key('next_evidence_plan_secondary_line'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ],
        if (result.showProLine) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            NextEvidencePlanCopy.proLineLongTerm,
            key: const Key('next_evidence_plan_pro_line'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('next_evidence_plan_pro_preview_button'),
              onPressed: () =>
                  context.push(NextEvidencePlanCopy.proPreviewRoute),
              child: const Text(NextEvidencePlanCopy.proPreviewButton),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton(
              key: const Key('next_evidence_plan_add_moment_button'),
              onPressed:
                  widget.onAddMoment ??
                  () => context.push(result.primaryActionRoute),
              child: Text(result.primaryActionLabel),
            ),
            if (result.showReviewWatchlistAction)
              OutlinedButton(
                key: const Key('next_evidence_plan_review_watchlist_button'),
                onPressed: widget.onReviewWatchlist,
                child: const Text(NextEvidencePlanCopy.reviewWatchlistAction),
              ),
          ],
        ),
      ],
    );
  }
}

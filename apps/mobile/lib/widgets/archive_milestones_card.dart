import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_milestones/archive_milestones_copy.dart';
import 'package:archiveme_mobile/features/archive_milestones/archive_milestones_engine.dart';
import 'package:archiveme_mobile/features/archive_milestones/archive_milestones_gates.dart';
import 'package:archiveme_mobile/features/archive_milestones/archive_milestones_models.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_store.dart';
import 'package:archiveme_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:archiveme_mobile/features/return_ritual/return_ritual_models.dart';
import 'package:archiveme_mobile/features/return_ritual/return_ritual_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Compact archive milestones card — computed locally, no journal writes.
class ArchiveMilestonesCard extends StatefulWidget {
  const ArchiveMilestonesCard({
    required this.entries, super.key,
    this.onAddMoment,
    this.watchlistStore,
    this.returnRitualStore,
    this.engine = const ArchiveMilestonesEngine(),
    this.initialWatchlistCount = 0,
    this._initialReturnRitual,
    this.sampleMode = false,
    this.skipPrefsLoad = false,
  });

  const ArchiveMilestonesCard.test({
    required this.entries, super.key,
    this.initialWatchlistCount = 0,
    this._initialReturnRitual,
    this.onAddMoment,
    this.watchlistStore,
    this.returnRitualStore,
    this.engine = const ArchiveMilestonesEngine(),
    this.sampleMode = false,
  }) : skipPrefsLoad = true;

  final List<JournalEntry> entries;
  final VoidCallback? onAddMoment;
  final ArchiveWatchlistStore? watchlistStore;
  final ReturnRitualStore? returnRitualStore;
  final ArchiveMilestonesEngine engine;
  final int initialWatchlistCount;
  final ReturnRitualChoice? _initialReturnRitual;
  final bool sampleMode;
  final bool skipPrefsLoad;

  @override
  State<ArchiveMilestonesCard> createState() => _ArchiveMilestonesCardState();
}

class _ArchiveMilestonesCardState extends State<ArchiveMilestonesCard> {
  ArchiveWatchlistStore? _watchlistStore;
  ReturnRitualStore? _returnRitualStore;
  int _watchlistCount = 0;
  bool _hasReturnRitual = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _watchlistStore = widget.watchlistStore;
    _returnRitualStore = widget.returnRitualStore;
    if (widget.skipPrefsLoad) {
      _watchlistCount = widget.initialWatchlistCount;
      _hasReturnRitual = widget._initialReturnRitual?.isValid == true;
      _loading = false;
      return;
    }
    if (widget.watchlistStore != null && widget.returnRitualStore != null) {
      unawaited(_loadFromStores());
      return;
    }
    unawaited(_load());
  }

  Future<void> _loadFromStores() async {
    final items = await _watchlistStore!.loadItems();
    final ritual = await _returnRitualStore!.load();
    if (!mounted) return;
    setState(() {
      _watchlistCount = items.length;
      _hasReturnRitual = ritual?.isValid == true;
      _loading = false;
    });
  }

  Future<void> _load() async {
    _watchlistStore ??= ArchiveWatchlistStore(AppServices.instance.prefs);
    _returnRitualStore ??= ReturnRitualStore(AppServices.instance.prefs);
    await _loadFromStores();
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveMilestonesGates.showOnArchive(sampleMode: widget.sampleMode)) {
      return const SizedBox.shrink(key: Key('archive_milestones_card_hidden'));
    }

    if (_loading) {
      return const SizedBox.shrink(key: Key('archive_milestones_card_loading'));
    }

    final result = widget.engine.build(
      entries: widget.entries,
      watchlistCount: _watchlistCount,
      hasReturnRitual: _hasReturnRitual,
    );

    return Container(
      key: const Key('archive_milestones_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('archive_milestones_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('archive_milestones_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in result.rows) _row(context, row),
          if (result.showProLine) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveMilestonesCopy.proLineLongTerm,
              key: const Key('archive_milestones_pro_line'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('archive_milestones_pro_preview_button'),
                onPressed: () =>
                    context.push(ArchiveMilestonesCopy.proPreviewRoute),
                child: const Text(ArchiveMilestonesCopy.proPreviewButton),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_milestones_add_moment_button'),
            onPressed:
                widget.onAddMoment ??
                () => context.push(result.primaryActionRoute),
            child: Text(result.primaryActionLabel),
          ),
          if (widget.entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('archive_milestones_milestone_share_button'),
              onPressed: () => context.push(MilestoneShareCopy.route),
              child: const Text(MilestoneShareCopy.openMilestoneCardsCta),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ArchiveMilestoneRow row) {
    return Padding(
      key: Key('archive_milestone_row_${row.id.name}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              ArchiveMilestonesCopy.stateLabel(row.state),
              key: Key('archive_milestone_state_${row.id.name}'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: row.state == ArchiveMilestoneRowState.done
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.label,
              key: Key('archive_milestone_label_${row.id.name}'),
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ),
        ],
      ),
    );
  }
}
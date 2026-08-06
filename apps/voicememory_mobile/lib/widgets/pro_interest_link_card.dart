import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../features/pro_interest/pro_interest_copy.dart';
import '../features/pro_interest/pro_interest_gates.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Subtle archive-home link to mark Pro interest — no payment.
class ProInterestLinkCard extends StatefulWidget {
  const ProInterestLinkCard({
    super.key,
    required this.entries,
    this.watchlistStore,
    this.sampleMode = false,
    this.skipPrefsLoad = false,
    this.initialWatchlistCount = 0,
  });

  const ProInterestLinkCard.test({
    super.key,
    required this.entries,
    this.initialWatchlistCount = 0,
    this.sampleMode = false,
  }) : watchlistStore = null,
       skipPrefsLoad = true;

  final List<JournalEntry> entries;
  final ArchiveWatchlistStore? watchlistStore;
  final bool sampleMode;
  final bool skipPrefsLoad;
  final int initialWatchlistCount;

  @override
  State<ProInterestLinkCard> createState() => _ProInterestLinkCardState();
}

class _ProInterestLinkCardState extends State<ProInterestLinkCard> {
  int _watchlistCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _watchlistCount = widget.initialWatchlistCount;
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
      _watchlistCount = items.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('pro_interest_link_card_loading'));
    }

    final entryCount = const BetaFeedbackEngine().realEntryCount(
      widget.entries,
    );
    if (!ProInterestGates.showArchiveLink(
      entryCount: entryCount,
      watchlistCount: _watchlistCount,
      sampleMode: widget.sampleMode,
    )) {
      return const SizedBox.shrink(key: Key('pro_interest_link_card_hidden'));
    }

    return Container(
      key: const Key('pro_interest_link_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProInterestCopy.archiveCardTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProInterestCopy.archiveCardBody,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('pro_interest_link_card_cta'),
            onPressed: () => context.push('/pro-interest'),
            child: const Text(ProInterestCopy.markProInterestButton),
          ),
        ],
      ),
    );
  }
}

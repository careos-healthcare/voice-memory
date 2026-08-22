import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_store.dart';
import 'package:archiveme_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:archiveme_mobile/features/milestone_share/milestone_share_engine.dart';
import 'package:archiveme_mobile/features/milestone_share/milestone_share_models.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';

/// Full milestone share cards screen — fixed copy only, no journal text.
class MilestoneShareCardsScreen extends StatefulWidget {
  const MilestoneShareCardsScreen({
    super.key,
    this.engine = const MilestoneShareEngine(),
    this._initialResult,
    this.watchlistStore,
  });

  final MilestoneShareEngine engine;
  final ArchiveWatchlistStore? watchlistStore;
  final MilestoneShareResult? _initialResult;

  @override
  State<MilestoneShareCardsScreen> createState() =>
      _MilestoneShareCardsScreenState();
}

class _MilestoneShareCardsScreenState extends State<MilestoneShareCardsScreen> {
  MilestoneShareResult? _result;
  bool _loading = true;
  final _copiedShareKeys = <String>{};

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
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = widget.engine.build(
          const MilestoneShareInput(
            realSavedMomentCount: 3,
            usableEvidenceCount: 3,
            firstWeekComplete: false,
            hasWatchTheme: false,
            weeklyReviewAvailable: false,
            hasRepeatingTheme: false,
            thenVsNowAvailable: false,
            archiveCalendarActiveAcrossDays: false,
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
    final entries = await AppServices.instance.journal.loadAll();
    final watchItems = await watchlist.loadItems();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: watchItems.isNotEmpty,
      );
      _loading = false;
    });
  }

  Future<void> _copyShareText(MilestoneShareCard card) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: MilestoneShareCopy.shareTextFor(card),
      showConfirmation: false,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      setState(() => _copiedShareKeys.add(card.milestoneId.name));
    }
  }

  Future<void> _copyTitleBody(MilestoneShareCard card) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: MilestoneShareCopy.titleBodyFor(card),
      showConfirmation: false,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      setState(() => _copiedShareKeys.add('${card.milestoneId.name}_body'));
    }
  }

  Future<void> _share(MilestoneShareCard card) async {
    final outcome = await ArchiveShareActions.shareShareText(
      context,
      text: MilestoneShareCopy.shareTextFor(card),
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.fallbackCopied) {
      setState(() => _copiedShareKeys.add(card.milestoneId.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: MilestoneShareCopy.screenTitle,
      fallbackRoute: '/archive-belief',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('milestone_share_cards_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, MilestoneShareResult result) {
    if (result.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.emptyTitle,
            key: const Key('milestone_share_empty_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.emptyBody,
            key: const Key('milestone_share_empty_body'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('milestone_share_empty_cta'),
            onPressed: () => context.push(result.emptyCtaRoute),
            child: Text(result.emptyCtaLabel),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          MilestoneShareCopy.screenIntro,
          key: const Key('milestone_share_screen_intro'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final card in result.cards) _card(context, card),
      ],
    );
  }

  Widget _card(BuildContext context, MilestoneShareCard card) {
    final shareCopied = _copiedShareKeys.contains(card.milestoneId.name);
    final bodyCopied = _copiedShareKeys.contains(
      '${card.milestoneId.name}_body',
    );

    return Container(
      key: Key('milestone_share_card_${card.milestoneId.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            key: Key('milestone_share_title_${card.milestoneId.name}'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            card.body,
            key: Key('milestone_share_body_${card.milestoneId.name}'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            card.safeShareText,
            key: Key('milestone_share_text_${card.milestoneId.name}'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            card.proofLabel,
            key: Key('milestone_share_proof_${card.milestoneId.name}'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                key: Key('milestone_share_copy_${card.milestoneId.name}'),
                onPressed: card.isShareable ? () => _copyShareText(card) : null,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(
                  shareCopied
                      ? MilestoneShareCopy.copiedLabel
                      : MilestoneShareCopy.copyShareTextCta,
                ),
              ),
              TextButton.icon(
                key: Key('milestone_share_copy_body_${card.milestoneId.name}'),
                onPressed: card.isShareable ? () => _copyTitleBody(card) : null,
                icon: const Icon(Icons.content_copy_outlined, size: 16),
                label: Text(
                  bodyCopied
                      ? MilestoneShareCopy.copiedLabel
                      : MilestoneShareCopy.copyTitleBodyCta,
                ),
              ),
              TextButton.icon(
                key: Key('milestone_share_share_${card.milestoneId.name}'),
                onPressed: card.isShareable ? () => _share(card) : null,
                icon: const Icon(Icons.ios_share_outlined, size: 16),
                label: const Text(MilestoneShareCopy.shareCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/share/archive_belief_share_card.dart';
import '../../features/share/archive_share_actions.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Hosts the belief share card below the value-moment cards. Re-evaluates
/// when session value signals change (useful-yes) so the card can appear
/// right after the moment, and latches once shown so it survives parent
/// rebuilds until dismissed.
class ArchiveBeliefShareSection extends StatefulWidget {
  const ArchiveBeliefShareSection({
    super.key,
    required this.hasBeliefDistance,
    required this.hasWeeklyReview,
    required this.hasThreadReturn,
    this.onShare,
  });

  final bool hasBeliefDistance;
  final bool hasWeeklyReview;
  final bool hasThreadReturn;

  /// Test hook; production uses the existing share_plus sheet.
  final Future<void> Function(String text)? onShare;

  @override
  State<ArchiveBeliefShareSection> createState() =>
      _ArchiveBeliefShareSectionState();
}

class _ArchiveBeliefShareSectionState extends State<ArchiveBeliefShareSection> {
  bool _showing = false;
  String _source = '';

  @override
  void initState() {
    super.initState();
    ArchiveBeliefShareCard.changes.addListener(_reevaluate);
  }

  @override
  void dispose() {
    ArchiveBeliefShareCard.changes.removeListener(_reevaluate);
    super.dispose();
  }

  void _reevaluate() {
    if (!mounted || _showing) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) {
      if (!ArchiveBeliefShareCard.shouldShow(
        hasBeliefDistance: widget.hasBeliefDistance,
        hasWeeklyReview: widget.hasWeeklyReview,
        hasThreadReturn: widget.hasThreadReturn,
      )) {
        return const SizedBox.shrink();
      }
      _showing = true;
      ArchiveBeliefShareCard.shownThisSession = true;
      _source =
          ArchiveBeliefShareCard.sourceFor(
            hasBeliefDistance: widget.hasBeliefDistance,
            hasWeeklyReview: widget.hasWeeklyReview,
            hasThreadReturn: widget.hasThreadReturn,
          ) ??
          '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ArchiveBeliefShareCardWidget(
        source: _source,
        onShare: widget.onShare,
        onDismissed: () => setState(() {
          ArchiveBeliefShareCard.dismissedThisSession = true;
          _showing = false;
        }),
      ),
    );
  }
}

/// The share card itself: a picker of generalized lines the user must
/// choose from, a card preview, and explicit Copy / Share / Not now
/// actions. Every visible string is a compile-time constant — nothing
/// from the archive can appear here.
class ArchiveBeliefShareCardWidget extends StatefulWidget {
  const ArchiveBeliefShareCardWidget({
    super.key,
    required this.source,
    required this.onDismissed,
    this.onShare,
  });

  /// Stable id of the value moment that made the card eligible.
  final String source;

  final VoidCallback onDismissed;

  /// Test hook; production uses the existing share_plus sheet.
  final Future<void> Function(String text)? onShare;

  @override
  State<ArchiveBeliefShareCardWidget> createState() =>
      _ArchiveBeliefShareCardWidgetState();
}

class _ArchiveBeliefShareCardWidgetState
    extends State<ArchiveBeliefShareCardWidget> {
  String? _selectedLineId;
  bool _copied = false;

  void _selectLine(String lineId) {
    if (_selectedLineId == lineId) return;
    setState(() {
      _selectedLineId = lineId;
      _copied = false;
    });
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBeliefShareLineSelected,
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      lineId: lineId,
    );
  }

  Future<void> _copy() async {
    final lineId = _selectedLineId;
    if (lineId == null) return;
    final text = ArchiveBeliefShareCard.copiedTextFor(lineId);
    if (!ArchiveShareActions.isShareable(text)) return;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBeliefShareCopied,
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      lineId: lineId,
    );
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: text,
      showConfirmation: false,
    );
    if (!mounted) return;
    ArchiveShareActions.trackShareAction(
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      shareType: 'copy',
      status: ArchiveShareActions.outcomeStatus(outcome),
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied) {
      setState(() => _copied = true);
    }
  }

  Future<void> _share() async {
    final lineId = _selectedLineId;
    if (lineId == null) return;
    final text = ArchiveBeliefShareCard.copiedTextFor(lineId);
    if (!ArchiveShareActions.isShareable(text)) return;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBeliefShareCopied,
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      lineId: lineId,
    );
    if (widget.onShare != null) {
      await widget.onShare!(text);
      if (!mounted) return;
      ArchiveShareActions.trackShareAction(
        source: widget.source,
        cardType: ArchiveBeliefShareCard.cardType,
        shareType: 'share',
        status: 'shared',
      );
      return;
    }
    final outcome = await ArchiveShareActions.shareShareText(
      context,
      text: text,
    );
    if (!mounted) return;
    ArchiveShareActions.trackShareAction(
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      shareType: outcome == ArchiveShareOutcome.fallbackCopied
          ? 'fallback_copy'
          : 'share',
      status: ArchiveShareActions.outcomeStatus(outcome),
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.fallbackCopied) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveBeliefShareCardSeen,
      source: widget.source,
      cardType: ArchiveBeliefShareCard.cardType,
      oncePerSession: true,
    );

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final selected = _selectedLineId == null
        ? null
        : ArchiveBeliefShareCard.lineFor(_selectedLineId!);
    final selectedText = _selectedLineId == null
        ? null
        : ArchiveBeliefShareCard.copiedTextFor(_selectedLineId!);
    final actionsEnabled = ArchiveShareActions.isShareable(selectedText);

    return Container(
      key: const Key('archive_belief_share_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveBeliefShareCard.title,
            key: const Key('archive_belief_share_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(ArchiveBeliefShareCard.pickerPrompt, style: helperStyle),
          const SizedBox(height: AppSpacing.sm),
          // The line picker — the user must explicitly choose one of the
          // generalized lines before anything can be copied or shared.
          ...ArchiveBeliefShareCard.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InkWell(
                key: Key('archive_belief_share_line_${line.id}'),
                onTap: () => _selectLine(line.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedLineId == line.id
                        ? const Color(0xFFE6E6F5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedLineId == line.id
                          ? AppColors.textPrimary
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    line.text,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: _selectedLineId == line.id
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                  ),
                ),
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: AppSpacing.xs),
            // Card preview — exactly what the copied text will say.
            Container(
              key: const Key('archive_belief_share_preview'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.text,
                    key: const Key('archive_belief_share_main_line'),
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ArchiveBeliefShareCard.footer,
                    key: const Key('archive_belief_share_footer'),
                    style: helperStyle,
                  ),
                  Text(
                    ArchiveBeliefShareCard.privacyLine,
                    key: const Key('archive_belief_share_privacy_line'),
                    style: helperStyle,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (_copied)
            Text(
              ArchiveBeliefShareCard.copiedConfirmation,
              key: const Key('archive_belief_share_copied_line'),
              style: helperStyle,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    key: const Key('archive_belief_share_dismiss'),
                    onPressed: () {
                      ActivationFunnelAnalytics.track(
                        ActivationFunnelAnalytics.archiveBeliefShareDismissed,
                        source: widget.source,
                        cardType: ArchiveBeliefShareCard.cardType,
                      );
                      widget.onDismissed();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    child: const Text(
                      ArchiveBeliefShareCard.dismissLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: TextButton.icon(
                    key: const Key('archive_belief_share_share'),
                    onPressed: actionsEnabled ? _share : null,
                    icon: const Icon(Icons.ios_share_outlined, size: 16),
                    label: const Text(
                      ArchiveBeliefShareCard.shareCtaLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: FilledButton(
                    key: const Key('archive_belief_share_copy'),
                    onPressed: actionsEnabled ? _copy : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: const Text(
                      ArchiveBeliefShareCard.copyCtaLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

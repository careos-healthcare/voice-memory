import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/chat_differentiation/chat_differentiation_copy.dart';
import '../../features/first_proof_payoff/first_proof_payoff_analytics.dart';
import '../../features/first_proof_payoff/first_proof_payoff_copy.dart';
import '../../features/first_proof_payoff/first_proof_payoff_model.dart';
import '../../features/pattern_confidence/pattern_confidence_model.dart';
import '../../features/pro_packaging/pro_value_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../patterns/pattern_confidence_badge.dart';
import '../common/contextual_privacy_reassurance.dart';
import '../common/pro_packaging_bridge_line.dart';
import 'chat_differentiation_sheet.dart';

/// Emotional first-proof payoff — user evidence first, calm CTAs elsewhere.
class FirstProofPayoffCard extends StatefulWidget {
  const FirstProofPayoffCard({
    super.key,
    required this.payoff,
    required this.entryCount,
    required this.onWatchThisNext,
    this.onViewPatternDetails,
    this.suppressCtas = false,
    this.patternConfidence,
    this.showProPackagingBridge = true,
  });

  final FirstProofPayoff payoff;
  final int entryCount;
  final VoidCallback onWatchThisNext;
  final VoidCallback? onViewPatternDetails;
  final bool suppressCtas;
  final PatternConfidence? patternConfidence;
  final bool showProPackagingBridge;

  @override
  State<FirstProofPayoffCard> createState() => _FirstProofPayoffCardState();
}

class _FirstProofPayoffCardState extends State<FirstProofPayoffCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    FirstProofPayoffAnalytics.seen(
      entryCount: widget.entryCount,
      hasSnippets: widget.payoff.hasSnippets,
      hasPatternDetailCta: widget.onViewPatternDetails != null,
    );
  }

  void _handleViewPatternDetails() {
    final onView = widget.onViewPatternDetails;
    if (onView == null) return;
    FirstProofPayoffAnalytics.ctaTapped(
      entryCount: widget.entryCount,
      hasSnippets: widget.payoff.hasSnippets,
      hasPatternDetailCta: true,
      cta: 'view_pattern_details',
    );
    onView();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final payoff = widget.payoff;
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final snippetStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );

    return Container(
      key: const Key('first_proof_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payoff.headline,
            key: const Key('first_proof_payoff_headline'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (widget.patternConfidence != null) ...[
            const SizedBox(height: AppSpacing.xs),
            PatternConfidenceBadge(confidence: widget.patternConfidence!),
          ],
          if (payoff.hasSnippets) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              payoff.evidenceLabel,
              key: const Key('first_proof_payoff_your_words_label'),
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final snippet in payoff.snippets) ...[
              Text(
                FirstProofPayoffCopy.formatBulletSnippet(snippet.quote),
                key: Key(
                  'first_proof_payoff_snippet_quote_${snippet.quote.hashCode}',
                ),
                style: snippetStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              payoff.meaningLine,
              key: const Key('first_proof_payoff_pattern_line'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            if (payoff.showDifferentiation) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                payoff.differentiationLine!,
                key: const Key('first_proof_payoff_differentiation_line'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('first_proof_payoff_chat_differentiation_link'),
                  onPressed: () => ChatDifferentiationSheet.show(
                    context,
                    timelineRows: payoff.timelineRows,
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    ChatDifferentiationCopy.expandLinkLabel,
                    style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              payoff.returnHook,
              key: const Key('first_proof_payoff_truth_line'),
              style: bodyStyle,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              payoff.returnHook,
              key: const Key('first_proof_payoff_fallback_body'),
              style: bodyStyle,
            ),
          ],
          if (!widget.suppressCtas && widget.onViewPatternDetails != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('first_proof_payoff_pattern_detail_cta'),
                onPressed: _handleViewPatternDetails,
                child: const Text(FirstProofPayoffCopy.viewPatternDetailsCta),
              ),
            ),
          ],
          if (widget.showProPackagingBridge) ...[
            const SizedBox(height: AppSpacing.sm),
            ProPackagingBridgeLine(
              line: ProPackagingCopy.bridgeAfterFirstProof,
              lineKey: const Key('pro_packaging_bridge_first_proof'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ContextualPrivacyReassurance(
            source: 'first_proof_payoff',
            entryCount: widget.entryCount,
          ),
        ],
      ),
    );
  }
}

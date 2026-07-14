import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/chat_differentiation/chat_differentiation_copy.dart';
import '../../features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import '../../features/beta_improvement/proof_emotional_clarity_model.dart';
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
import 'proof_emotional_clarity_correction_row.dart';

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
    final emotional = payoff.emotionalClarity;
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final snippetStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );

    if (emotional != null) {
      return _buildEmotionalClarityCard(
        context,
        payoff: payoff,
        emotional: emotional,
        bodyStyle: bodyStyle,
        snippetStyle: snippetStyle,
      );
    }

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

  Widget _buildEmotionalClarityCard(
    BuildContext context, {
    required FirstProofPayoff payoff,
    required ProofEmotionalClarityDisplay emotional,
    required TextStyle bodyStyle,
    required TextStyle snippetStyle,
  }) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('first_proof_payoff_emotional_clarity_card'),
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
          if (payoff.subhead.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              payoff.subhead,
              key: const Key('first_proof_payoff_subheadline'),
              style: bodyStyle,
            ),
          ],
          if (emotional.evidenceLine?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              emotional.evidenceLine!,
              key: const Key('first_proof_payoff_evidence_line'),
              style: labelStyle,
            ),
          ],
          if (emotional.whatCameBackBody?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ProofEmotionalClarityCopyFix.whatCameBackLabel,
              key: const Key('first_proof_payoff_what_came_back_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              emotional.whatCameBackBody!,
              key: const Key('first_proof_payoff_what_came_back_body'),
              style: snippetStyle,
            ),
          ],
          if (emotional.whatChangedBody?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ProofEmotionalClarityCopyFix.whatChangedLabel,
              key: const Key('first_proof_payoff_what_changed_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              emotional.whatChangedBody!,
              key: const Key('first_proof_payoff_what_changed_body'),
              style: bodyStyle,
            ),
          ],
          if (emotional.whyItMightMatterBody?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ProofEmotionalClarityCopyFix.whyItMightMatterLabel,
              key: const Key('first_proof_payoff_why_matters_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              emotional.whyItMightMatterBody!,
              key: const Key('first_proof_payoff_why_matters_body'),
              style: bodyStyle,
            ),
          ],
          if (emotional.showCorrectionRow) ...[
            ProofEmotionalClarityCorrectionRow(entryCount: widget.entryCount),
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
          Text(
            ProofEmotionalClarityCopyFix.cautionFooter,
            key: const Key('first_proof_payoff_caution_footer'),
            style: bodyStyle,
          ),
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

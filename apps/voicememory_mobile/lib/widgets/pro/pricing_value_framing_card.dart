import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pricing_value_framing/pricing_value_framing_analytics.dart';
import '../../features/pricing_value_framing/pricing_value_framing_copy.dart';
import '../../features/pricing_value_framing/pricing_value_framing_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class PricingValueFramingCard extends StatefulWidget {
  const PricingValueFramingCard({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  const PricingValueFramingCard.test({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  final PricingValueFramingResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<PricingValueFramingCard> createState() =>
      _PricingValueFramingCardState();
}

class _PricingValueFramingCardState extends State<PricingValueFramingCard> {
  var _trackedSeen = false;
  var _dismissed = false;
  PricingValueFramingFeedbackType? _feedback;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissed) return;
    _trackedSeen = true;
    PricingValueFramingAnalytics.seen(result: widget.result);
  }

  void _selectFeedback(PricingValueFramingFeedbackType feedback) {
    PricingValueFramingAnalytics.feedbackSelected(
      result: widget.result,
      feedback: feedback,
    );
    setState(() => _feedback = feedback);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('pricing_value_framing_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('pricing_value_framing_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pricing_value_framing_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('pricing_value_framing_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.valueExplanation,
            key: const Key('pricing_value_framing_value_explanation'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          for (final bullet in widget.result.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: bodyStyle.copyWith(color: AppColors.textPrimary)),
                  Expanded(
                    child: Text(
                      bullet,
                      key: Key('pricing_value_framing_bullet_$bullet'),
                      style: bodyStyle.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            widget.result.reassurance,
            key: const Key('pricing_value_framing_reassurance'),
            style: bodyStyle,
          ),
          if (_feedback == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.feedbackPrompt,
              key: const Key('pricing_value_framing_feedback_prompt'),
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final type in PricingValueFramingFeedbackType.values)
                  TextButton(
                    key: Key(
                      'pricing_value_framing_feedback_${type.analyticsValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => _selectFeedback(type),
                    child: Text(PricingValueFramingCopy.feedbackLabel(type)),
                  ),
              ],
            ),
          ],
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('pricing_value_framing_primary_cta'),
            onPressed: () {
              PricingValueFramingAnalytics.ctaTapped(result: widget.result);
              widget.onSeePro();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('pricing_value_framing_secondary_cta'),
            onPressed: () => setState(() => _dismissed = true),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_analytics.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_copy.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class PricingValidationCard extends StatefulWidget {
  const PricingValidationCard({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  const PricingValidationCard.test({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  final PricingValidationResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<PricingValidationCard> createState() => _PricingValidationCardState();
}

class _PricingValidationCardState extends State<PricingValidationCard> {
  var _trackedSeen = false;
  var _dismissed = false;
  PricingValidationPriceOption? _selectedPrice;
  PricingValidationReasonOption? _selectedReason;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissed) return;
    _trackedSeen = true;
    PricingValidationAnalytics.seen(result: widget.result);
  }

  void _selectPrice(PricingValidationPriceOption price) {
    PricingValidationAnalytics.priceSelected(
      result: widget.result,
      price: price,
    );
    setState(() => _selectedPrice = price);
  }

  void _selectReason(PricingValidationReasonOption reason) {
    PricingValidationAnalytics.reasonSelected(
      result: widget.result,
      reason: reason,
    );
    setState(() => _selectedReason = reason);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('pricing_validation_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final promptStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('pricing_validation_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pricing_validation_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('pricing_validation_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (_selectedPrice == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.pricePrompt,
              key: const Key('pricing_validation_price_prompt'),
              style: promptStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in PricingValidationCopy.priceOptions)
                  TextButton(
                    key: Key(
                      'pricing_validation_price_${option.analyticsValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => _selectPrice(option),
                    child: Text(PricingValidationCopy.priceLabel(option)),
                  ),
              ],
            ),
          ],
          if (_selectedReason == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.reasonPrompt,
              key: const Key('pricing_validation_reason_prompt'),
              style: promptStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in PricingValidationCopy.reasonOptions)
                  TextButton(
                    key: Key(
                      'pricing_validation_reason_${option.analyticsValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => _selectReason(option),
                    child: Text(PricingValidationCopy.reasonLabel(option)),
                  ),
              ],
            ),
          ],
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('pricing_validation_primary_cta'),
            onPressed: () {
              PricingValidationAnalytics.ctaTapped(result: widget.result);
              widget.onSeePro();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('pricing_validation_secondary_cta'),
            onPressed: () => setState(() => _dismissed = true),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
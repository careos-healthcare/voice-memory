import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_analytics.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_copy.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_model.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_analytics.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class FirstSaveLiftCard extends StatefulWidget {
  const FirstSaveLiftCard({
    required this.result, required this.onTypeOneSentence, required this.onRecordInstead, required this.onExampleSelected, super.key,
  });

  const FirstSaveLiftCard.test({
    required this.result, required this.onTypeOneSentence, required this.onRecordInstead, required this.onExampleSelected, super.key,
  });

  final FirstSaveLiftResult result;
  final VoidCallback onTypeOneSentence;
  final VoidCallback onRecordInstead;
  final ValueChanged<String> onExampleSelected;

  @override
  State<FirstSaveLiftCard> createState() => _FirstSaveLiftCardState();
}

class _FirstSaveLiftCardState extends State<FirstSaveLiftCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    FirstSaveLiftAnalytics.seen(result: widget.result);
    RevenueLiftExperimentV2Analytics.seen(
      context: RevenueLiftExperimentV2SeenContext(
        source: widget.result.source,
        surface: 'first_save_lift_card',
        entryCount: widget.result.entryCount,
        area: RevenueLiftExperimentV2Area.firstSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('first_save_lift_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('first_save_lift_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('first_save_lift_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('first_save_lift_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final example in widget.result.examples)
                ActionChip(
                  key: Key(
                    'first_save_lift_example_${FirstSaveLiftCopy.exampleAnalyticsId(example.id)}',
                  ),
                  label: Text(example.text),
                  onPressed: () {
                    FirstSaveLiftAnalytics.exampleTapped(
                      result: widget.result,
                      exampleId: example.id,
                    );
                    widget.onExampleSelected(example.text);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_save_lift_primary_cta'),
            onPressed: () {
              FirstSaveLiftAnalytics.ctaTapped(
                result: widget.result,
                actionType: FirstSaveLiftActionType.typeOneSentence,
              );
              RevenueLiftExperimentV2Analytics.ctaTapped(
                context: RevenueLiftExperimentV2CtaContext(
                  source: widget.result.source,
                  surface: 'first_save_lift_card',
                  entryCount: widget.result.entryCount,
                  area: RevenueLiftExperimentV2Area.firstSave,
                ),
              );
              widget.onTypeOneSentence();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('first_save_lift_secondary_cta'),
            onPressed: () {
              FirstSaveLiftAnalytics.ctaTapped(
                result: widget.result,
                actionType: FirstSaveLiftActionType.recordInstead,
              );
              widget.onRecordInstead();
            },
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
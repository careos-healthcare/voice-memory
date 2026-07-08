import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_save_lift/first_save_lift_analytics.dart';
import '../../features/first_save_lift/first_save_lift_copy.dart';
import '../../features/first_save_lift/first_save_lift_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class FirstSaveLiftCard extends StatefulWidget {
  const FirstSaveLiftCard({
    super.key,
    required this.result,
    required this.onTypeOneSentence,
    required this.onRecordInstead,
    required this.onExampleSelected,
  });

  const FirstSaveLiftCard.test({
    super.key,
    required this.result,
    required this.onTypeOneSentence,
    required this.onRecordInstead,
    required this.onExampleSelected,
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
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('first_save_lift_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

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

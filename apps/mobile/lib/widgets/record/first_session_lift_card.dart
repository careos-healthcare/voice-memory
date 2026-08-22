import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_analytics.dart';
import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_copy.dart';
import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class FirstSessionLiftCard extends StatefulWidget {
  const FirstSessionLiftCard({
    required this.result, required this.onTypeOneSentence, required this.onUseVoiceInstead, required this.onChipSelected, super.key,
  });

  const FirstSessionLiftCard.test({
    required this.result, required this.onTypeOneSentence, required this.onUseVoiceInstead, required this.onChipSelected, super.key,
  });

  final FirstSessionLiftResult result;
  final VoidCallback onTypeOneSentence;
  final VoidCallback onUseVoiceInstead;
  final ValueChanged<String> onChipSelected;

  @override
  State<FirstSessionLiftCard> createState() => _FirstSessionLiftCardState();
}

class _FirstSessionLiftCardState extends State<FirstSessionLiftCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    FirstSessionLiftAnalytics.seen(result: widget.result);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('first_session_lift_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('first_session_lift_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('first_session_lift_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('first_session_lift_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final chip in widget.result.chips)
                ActionChip(
                  key: Key(
                    'first_session_lift_chip_${FirstSessionLiftCopy.chipAnalyticsId(chip.id)}',
                  ),
                  label: Text(chip.text),
                  onPressed: () {
                    FirstSessionLiftAnalytics.chipTapped(
                      result: widget.result,
                      chipId: chip.id,
                    );
                    widget.onChipSelected(chip.text);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_session_lift_primary_cta'),
            onPressed: () {
              FirstSessionLiftAnalytics.ctaTapped(
                result: widget.result,
                actionType: FirstSessionLiftActionType.typeOneSentence,
              );
              widget.onTypeOneSentence();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('first_session_lift_secondary_cta'),
            onPressed: () {
              FirstSessionLiftAnalytics.ctaTapped(
                result: widget.result,
                actionType: FirstSessionLiftActionType.useVoiceInstead,
              );
              widget.onUseVoiceInstead();
            },
            child: Text(widget.result.secondaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.microcopy,
            key: const Key('first_session_lift_microcopy'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_run_positioning/first_run_positioning_engine.dart';
import 'package:archiveme_mobile/features/first_run_positioning/first_run_positioning_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Early revenue positioning — education only, no paywall or Pro CTA.
class FirstRunPositioningCard extends StatefulWidget {
  const FirstRunPositioningCard({required this.result, super.key});

  const FirstRunPositioningCard.test({required this.result, super.key});

  final FirstRunPositioningResult result;

  @override
  State<FirstRunPositioningCard> createState() =>
      _FirstRunPositioningCardState();
}

class _FirstRunPositioningCardState extends State<FirstRunPositioningCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    FirstRunPositioningAnalytics.seen(result: widget.result);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('first_run_positioning_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('first_run_positioning_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('first_run_positioning_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.footer,
            key: const Key('first_run_positioning_footer'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
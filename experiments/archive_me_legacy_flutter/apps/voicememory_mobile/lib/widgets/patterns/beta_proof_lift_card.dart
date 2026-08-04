import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_proof_lift/beta_proof_lift_analytics.dart';
import '../../features/beta_proof_lift/beta_proof_lift_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Explains why a proof moment is showing — generic safe copy only.
class BetaProofLiftCard extends StatefulWidget {
  const BetaProofLiftCard({
    super.key,
    required this.result,
    required this.source,
    this.surface = 'record',
  });

  const BetaProofLiftCard.test({
    super.key,
    required this.result,
    required this.source,
    this.surface = 'record',
  });

  final BetaProofLiftResult result;
  final String source;
  final String surface;

  @override
  State<BetaProofLiftCard> createState() => _BetaProofLiftCardState();
}

class _BetaProofLiftCardState extends State<BetaProofLiftCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    BetaProofLiftAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) return const SizedBox.shrink();
    _trackSeenOnce();

    final sectionTitleStyle = ArchiveMobileTypography.responsiveSectionTitle(
      context,
    ).copyWith(fontSize: 15);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final deltaStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('beta_proof_lift_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F4EF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_proof_lift_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('beta_proof_lift_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final section in widget.result.sections) ...[
            Text(
              section.heading,
              key: Key('beta_proof_lift_section_${section.heading}'),
              style: sectionTitleStyle,
            ),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              section.body,
              key: Key('beta_proof_lift_section_body_${section.heading}'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (widget.result.deltaRows.isNotEmpty) ...[
            Text('Timeline signals', style: sectionTitleStyle),
            const SizedBox(height: AppSpacing.xs / 2),
            for (final row in widget.result.deltaRows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs / 2),
                child: Text(
                  row,
                  key: Key('beta_proof_lift_delta_${row.hashCode}'),
                  style: deltaStyle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

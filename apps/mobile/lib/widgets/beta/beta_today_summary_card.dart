import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_today_summary/beta_today_summary_analytics.dart';
import 'package:archiveme_mobile/features/beta_today_summary/beta_today_summary_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact beta today summary — optional recording, existing signals only.
class BetaTodaySummaryCard extends StatefulWidget {
  const BetaTodaySummaryCard({required this.result, super.key});

  const BetaTodaySummaryCard.test({required this.result, super.key});

  final BetaTodaySummaryResult result;

  @override
  State<BetaTodaySummaryCard> createState() => _BetaTodaySummaryCardState();
}

class _BetaTodaySummaryCardState extends State<BetaTodaySummaryCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    BetaTodaySummaryAnalytics.seen(result: widget.result);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final rowStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('beta_today_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_today_summary_title'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: Key(
              widget.result.usesFallbackBody
                  ? 'beta_today_summary_fallback_body'
                  : 'beta_today_summary_primary_body',
            ),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (widget.result.summaryRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final row in widget.result.summaryRows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  row,
                  key: Key('beta_today_summary_row_${row.hashCode}'),
                  style: rowStyle,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.closingLine,
            key: const Key('beta_today_summary_closing'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
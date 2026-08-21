import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_tester_report/beta_tester_report_analytics.dart';
import 'package:archiveme_mobile/features/beta_tester_report/beta_tester_report_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Beta-first report card — local UI only, no export or subscription CTA.
class BetaTesterReportCard extends StatefulWidget {
  const BetaTesterReportCard({required this.result, super.key});

  const BetaTesterReportCard.test({required this.result, super.key});

  final BetaTesterReportResult result;

  @override
  State<BetaTesterReportCard> createState() => _BetaTesterReportCardState();
}

class _BetaTesterReportCardState extends State<BetaTesterReportCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    BetaTesterReportAnalytics.seen(result: widget.result);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final headingStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('beta_tester_report_card'),
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
            key: const Key('beta_tester_report_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.subtitle,
            key: const Key('beta_tester_report_subtitle'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final section in widget.result.sections) ...[
            Text(
              section.heading,
              key: Key('beta_tester_report_heading_${section.id.name}'),
              style: headingStyle,
            ),
            const SizedBox(height: 4),
            Text(
              section.body,
              key: Key('beta_tester_report_body_${section.id.name}'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            widget.result.footer,
            key: const Key('beta_tester_report_footer'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.betaFeedbackLine,
            key: const Key('beta_tester_report_beta_feedback'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
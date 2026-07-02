import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/private_archive_report_analytics.dart';
import '../../features/early_archive/private_archive_report_copy.dart';
import '../../features/early_archive/private_archive_report_gates.dart';
import '../../features/early_archive/private_archive_report_model.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Private archive report card — evidence summary for personal ownership.
class PrivateArchiveReportCard extends StatefulWidget {
  const PrivateArchiveReportCard({
    super.key,
    required this.report,
    required this.entryCount,
    required this.surface,
    required this.isPro,
    this.onCopy,
    this.onShare,
    this.onSeePro,
  });

  const PrivateArchiveReportCard.test({
    super.key,
    required this.report,
    required this.entryCount,
    required this.surface,
    this.isPro = false,
    this.onCopy,
    this.onShare,
    this.onSeePro,
  });

  final PrivateArchiveReport report;
  final int entryCount;
  final String surface;
  final bool isPro;
  final Future<bool> Function(String text)? onCopy;
  final Future<bool> Function(String text)? onShare;
  final VoidCallback? onSeePro;

  @override
  State<PrivateArchiveReportCard> createState() =>
      _PrivateArchiveReportCardState();
}

class _PrivateArchiveReportCardState extends State<PrivateArchiveReportCard> {
  bool _seenLogged = false;

  bool get _isFullExport =>
      PrivateArchiveReportGates.showFullExport(isPro: widget.isPro);

  String get _exportText =>
      widget.report.plainText(isPro: _isFullExport);

  @override
  Widget build(BuildContext context) {
    if (!_seenLogged) {
      _seenLogged = true;
      PrivateArchiveReportAnalytics.seen(
        surface: widget.surface,
        entryCount: widget.entryCount,
        isFullExport: _isFullExport,
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final sectionLabelStyle = ArchiveMobileTypography.cardLabel(context);
    final previewStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('private_archive_report_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF7F8FA)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.report.title,
            key: const Key('private_archive_report_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.report.intro,
            key: const Key('private_archive_report_intro'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < widget.report.sections.length; i++)
            if (PrivateArchiveReportGates.includeSectionInPreview(
              sectionIndex: i,
              isPro: _isFullExport,
              previewSectionCount: widget.report.previewSectionCount,
            ))
              _SectionPreview(
                section: widget.report.sections[i],
                labelStyle: sectionLabelStyle,
                bodyStyle: bodyStyle,
              ),
          if (PrivateArchiveReportGates.showPreviewNote(isPro: widget.isPro)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              PrivateArchiveReportCopy.previewTitle,
              key: const Key('private_archive_report_preview_title'),
              style: ArchiveMobileTypography.listTitle(context).copyWith(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PrivateArchiveReportCopy.previewBody,
              key: const Key('private_archive_report_preview_body'),
              style: previewStyle,
            ),
            if (widget.onSeePro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('private_archive_report_see_pro_cta'),
                  onPressed: widget.onSeePro,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(PrivateArchiveReportCopy.previewProCta),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('private_archive_report_copy_cta'),
              onPressed: () => _copy(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(PrivateArchiveReportCopy.copyReportCta),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('private_archive_report_share_cta'),
              onPressed: () => _share(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(PrivateArchiveReportCopy.sharePrivatelyCta),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    PrivateArchiveReportAnalytics.copyTapped(
      surface: widget.surface,
      entryCount: widget.entryCount,
      isFullExport: _isFullExport,
    );
    if (widget.onCopy != null) {
      await widget.onCopy!(_exportText);
      return;
    }
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: _exportText,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied) {
      ArchiveShareActions.showFeedback(
        context,
        PrivateArchiveReportCopy.copyConfirmation,
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    PrivateArchiveReportAnalytics.shareTapped(
      surface: widget.surface,
      entryCount: widget.entryCount,
      isFullExport: _isFullExport,
    );
    if (widget.onShare != null) {
      await widget.onShare!(_exportText);
      return;
    }
    final outcome = await ArchiveShareActions.shareShareText(
      context,
      text: _exportText,
      subject: widget.report.title,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        PrivateArchiveReportCopy.shareFallbackMessage,
      );
    }
  }
}

class _SectionPreview extends StatelessWidget {
  const _SectionPreview({
    required this.section,
    required this.labelStyle,
    required this.bodyStyle,
  });

  final PrivateArchiveReportSection section;
  final TextStyle labelStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.heading,
            key: Key('private_archive_report_section_${section.heading}'),
            style: labelStyle,
          ),
          for (final line in section.lines)
            if (line.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(line, style: bodyStyle),
              ),
          for (final bullet in section.bullets)
            if (bullet.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('- $bullet', style: bodyStyle),
              ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/private_archive_report_analytics.dart';
import '../../features/early_archive/private_archive_report_copy.dart';
import '../../features/early_archive/private_archive_report_gates.dart';
import '../../features/early_archive/private_archive_report_model.dart';
import '../../features/private_report/private_report_copy.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../private_report/private_report_sheet.dart';

/// Private archive report card — evidence summary for personal ownership.
class PrivateArchiveReportCard extends StatefulWidget {
  const PrivateArchiveReportCard({
    super.key,
    required this.report,
    required this.entryCount,
    required this.surface,
    required this.isPro,
    this.onCopy,
    this.onSeePro,
  });

  const PrivateArchiveReportCard.test({
    super.key,
    required this.report,
    required this.entryCount,
    required this.surface,
    this.isPro = false,
    this.onCopy,
    this.onSeePro,
  });

  final PrivateArchiveReport report;
  final int entryCount;
  final String surface;
  final bool isPro;
  final Future<bool> Function(String text)? onCopy;
  final VoidCallback? onSeePro;

  @override
  State<PrivateArchiveReportCard> createState() =>
      _PrivateArchiveReportCardState();
}

class _PrivateArchiveReportCardState extends State<PrivateArchiveReportCard> {
  bool _seenLogged = false;

  bool get _isFullExport =>
      PrivateArchiveReportGates.showFullExport(isPro: widget.isPro);

  String get _exportText => widget.report.visiblePlainText(
        isPro: _isFullExport,
        previewSectionCount: widget.report.previewSectionCount,
      );

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
          _ExportScopeList(
            heading: PrivateArchiveReportCopy.exportIncludedHeading,
            items: PrivateArchiveReportCopy.exportIncludedItems,
            headingKey: const Key('private_archive_report_export_included_heading'),
            listKey: const Key('private_archive_report_export_included'),
            labelStyle: sectionLabelStyle,
            bodyStyle: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExportScopeList(
            heading: PrivateArchiveReportCopy.exportNotIncludedHeading,
            items: PrivateArchiveReportCopy.exportNotIncludedItems,
            headingKey:
                const Key('private_archive_report_export_not_included_heading'),
            listKey: const Key('private_archive_report_export_not_included'),
            labelStyle: sectionLabelStyle,
            bodyStyle: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('private_archive_report_view_cta'),
              onPressed: () => _openSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(PrivateArchiveReportCopy.viewReportCta),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('private_archive_report_copy_cta'),
              onPressed: () => _copy(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(PrivateArchiveReportCopy.copyReportCta),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) {
    return PrivateReportSheet.show(
      context,
      report: widget.report,
      entryCount: widget.entryCount,
      source: widget.surface,
      isPro: widget.isPro,
      hasChange: _sectionHasEvidence(PrivateReportCopy.whatChangedHeading),
      hasHelped: _sectionHasEvidence(PrivateReportCopy.whatHelpedHeading),
      onCopy: widget.onCopy,
    );
  }

  bool _sectionHasEvidence(String heading) {
    for (final section in widget.report.sections) {
      if (section.heading == heading) return section.hasEvidence;
    }
    return false;
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

class _ExportScopeList extends StatelessWidget {
  const _ExportScopeList({
    required this.heading,
    required this.items,
    required this.headingKey,
    required this.listKey,
    required this.labelStyle,
    required this.bodyStyle,
  });

  final String heading;
  final List<String> items;
  final Key headingKey;
  final Key listKey;
  final TextStyle labelStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, key: headingKey, style: labelStyle),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '- $item',
              key: Key('${listKey.toString()}_$item'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

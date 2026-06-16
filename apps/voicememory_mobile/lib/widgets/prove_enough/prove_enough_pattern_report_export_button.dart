import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/prove_enough_pattern_report_model.dart';
import '../../features/prove_enough/prove_enough_pattern_report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Pro-gated export for the prove_enough personal pattern report.
class ProveEnoughPatternReportExportButton extends StatefulWidget {
  const ProveEnoughPatternReportExportButton({
    super.key,
    required this.isPro,
    this.initialReport,
    this.onSeePro,
    this.onExport,
  });

  final bool isPro;

  @visibleForTesting
  final ProveEnoughPatternReport? initialReport;

  @visibleForTesting
  final VoidCallback? onSeePro;

  @visibleForTesting
  final Future<void> Function(ProveEnoughPatternReport report)? onExport;

  static const buttonLabel = 'Export pattern report';

  @override
  State<ProveEnoughPatternReportExportButton> createState() =>
      _ProveEnoughPatternReportExportButtonState();
}

class _ProveEnoughPatternReportExportButtonState
    extends State<ProveEnoughPatternReportExportButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (!widget.isPro) {
      await _showProGate();
      return;
    }
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final report =
          widget.initialReport ??
          await ProveEnoughPatternReportService.loadReport();
      if (!report.hasExportableContent) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save a few proving moments before exporting a pattern report.',
            ),
          ),
        );
        return;
      }

      if (widget.onExport != null) {
        await widget.onExport!(report);
      } else {
        await ProveEnoughPatternReportService.shareReport(report);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showProGate() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('prove_enough_pattern_report_pro_gate'),
        title: Text(ProveEnoughPatternReport.proGateTitle),
        content: const Text(
          'Export a personal pattern report with your saved proving-enough evidence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('prove_enough_pattern_report_see_pro_cta'),
            onPressed: widget.onSeePro == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onSeePro!();
                  },
            child: const Text('See Pro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('prove_enough_pattern_report_export_button'),
          onPressed: _busy ? null : _handleTap,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(
            _busy
                ? 'Preparing export…'
                : ProveEnoughPatternReportExportButton.buttonLabel,
          ),
        ),
        if (!widget.isPro) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: const Key('prove_enough_pattern_report_pro_hint'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: VoiceMemoryCards.standard(
              background: AppColors.accentLight,
            ),
            child: Text(
              ProveEnoughPatternReport.proGateTitle,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

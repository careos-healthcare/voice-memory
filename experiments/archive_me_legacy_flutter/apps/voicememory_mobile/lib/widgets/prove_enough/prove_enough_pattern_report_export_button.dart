import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/prove_enough/prove_enough_pattern_report_model.dart';
import '../../features/prove_enough/prove_enough_pattern_report_service.dart';

/// User-owned export. Subscription state must never gate this action.
class ProveEnoughPatternReportExportButton extends StatefulWidget {
  const ProveEnoughPatternReportExportButton({
    super.key,
    this.initialReport,
    this.onExport,
  });

  @visibleForTesting
  final ProveEnoughPatternReport? initialReport;

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
      ],
    );
  }
}

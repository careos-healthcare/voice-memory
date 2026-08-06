import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/developer_settings_gate.dart';
import '../../features/beta/beta_report_export_copy.dart';
import '../../features/beta/beta_report_export_model.dart';

/// Developer-only beta report copy action — clipboard only, no user content.
class BetaReportExportCard extends StatelessWidget {
  const BetaReportExportCard({
    super.key,
    required this.report,
    this.onCopied,
    this.copyText,
  });

  const BetaReportExportCard.test({
    super.key,
    required this.report,
    this.onCopied,
    this.copyText,
  });

  final BetaReportExport report;
  final VoidCallback? onCopied;
  final Future<void> Function(String text)? copyText;

  Future<void> _copyReport(BuildContext context) async {
    final copy =
        copyText ?? (text) => Clipboard.setData(ClipboardData(text: text));
    await copy(report.formattedText);
    onCopied?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(BetaReportExportCopy.copiedConfirmation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(key: Key('beta_report_export_hidden'));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        key: const Key('beta_report_export_copy_button'),
        onPressed: () => _copyReport(context),
        child: const Text(BetaReportExportCopy.copyButtonLabel),
      ),
    );
  }
}

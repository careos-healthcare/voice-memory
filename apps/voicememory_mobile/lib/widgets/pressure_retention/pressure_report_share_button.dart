import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Pro-only "share pressure report" action.
///
/// Reuses the existing share_plus pattern used elsewhere in the app. The
/// [onShare] hook keeps it testable without invoking platform share sheets.
class PressureReportShareButton extends StatelessWidget {
  const PressureReportShareButton({
    super.key,
    required this.reportText,
    this.onShare,
  });

  final String reportText;

  @visibleForTesting
  final Future<void> Function(String text)? onShare;

  static const label = 'Share pressure report';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('pressure_report_share_button'),
        onPressed: () => (onShare ?? _defaultShare)(reportText),
        icon: const Icon(Icons.ios_share_outlined),
        label: const Text(label),
      ),
    );
  }

  Future<void> _defaultShare(String text) => Share.share(text);
}

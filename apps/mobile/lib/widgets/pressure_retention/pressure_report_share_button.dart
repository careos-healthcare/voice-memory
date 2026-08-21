import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:flutter/material.dart';

/// Pro-only "share pressure report" action.
///
/// Reuses [ArchiveShareActions] for iPad-safe native share with copy fallback.
class PressureReportShareButton extends StatelessWidget {
  const PressureReportShareButton({
    required this.reportText, super.key,
    this.onShare,
  });

  final String reportText;

  @visibleForTesting
  final Future<void> Function(String text)? onShare;

  static const label = 'Share pressure report';

  @override
  Widget build(BuildContext context) {
    final enabled = ArchiveShareActions.isShareable(reportText);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('pressure_report_share_button'),
        onPressed: enabled
            ? () async {
                if (onShare != null) {
                  await onShare!(reportText);
                  return;
                }
                await ArchiveShareActions.shareShareText(
                  context,
                  text: reportText,
                );
              }
            : null,
        icon: const Icon(Icons.ios_share_outlined),
        label: const Text(label),
      ),
    );
  }
}
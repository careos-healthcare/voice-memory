import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:flutter/material.dart';

/// Shown on Archive when a legacy Changes deep link opens before eligibility.
class ArchiveChangesUnavailableNotice extends StatelessWidget {
  const ArchiveChangesUnavailableNotice({super.key});

  static const Key noticeKey = Key('archive_changes_unavailable_notice');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      label:
          '${ConsumerUiCopy.needMoreReflectionsTitle}. '
          '${ConsumerUiCopy.needMoreReflectionsBody}',
      child: Card(
        key: noticeKey,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ConsumerUiCopy.needMoreReflectionsTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                ConsumerUiCopy.needMoreReflectionsBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

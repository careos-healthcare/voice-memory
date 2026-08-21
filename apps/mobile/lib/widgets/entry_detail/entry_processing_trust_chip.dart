import 'package:archiveme_mobile/features/entry_detail/entry_processing_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/timeline_sync_badge.dart';
import 'package:flutter/material.dart';

/// Surfaces whether an entry was analyzed on-device or sent for cloud processing.
class EntryProcessingTrustChip extends StatelessWidget {
  const EntryProcessingTrustChip({required this.entry, super.key});

  final JournalEntry entry;

  static String? labelFor(JournalEntry entry) {
    final usedOnnx = entry.processingUsedOnnx;
    if (usedOnnx == null) return null;
    return usedOnnx
        ? EntryProcessingCopy.processedOnDevice
        : EntryProcessingCopy.sentForSecureProcessing;
  }

  @override
  Widget build(BuildContext context) {
    final label = labelFor(entry);
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TimelineSyncBadge(
        key: Key(
          entry.processingUsedOnnx == true
              ? 'entry_processing_on_device_chip'
              : 'entry_processing_cloud_chip',
        ),
        label: label,
      ),
    );
  }
}

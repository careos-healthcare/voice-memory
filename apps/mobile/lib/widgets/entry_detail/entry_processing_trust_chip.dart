import 'package:archiveme_mobile/features/entry_detail/entry_processing_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/timeline_sync_badge.dart';
import 'package:flutter/material.dart';

/// Surfaces whether an entry was analyzed on-device or sent for cloud processing.
class EntryProcessingTrustChip extends StatelessWidget {
  const EntryProcessingTrustChip({required this.entry, super.key});

  final JournalEntry entry;

  /// The provenance claim for [entry], or null when this build makes none.
  ///
  /// [JournalEntry.processingUsedOnnx] answers first because it is the only
  /// flag that distinguishes local analysis from remote: true means ONNX ran
  /// here, false means the entry was sent. Null is a third state, not a
  /// missing second one — a `SFSpeechRecognizer` transcript is neither ONNX
  /// nor uploaded, and it used to be recorded as `usedOnnx: true` purely to
  /// light this chip, which was true about the device and false about the
  /// model. Correcting that to null left the most private path showing no
  /// provenance at all, which is backwards; [JournalEntry.processingUsedLocalStt]
  /// is what recovers it.
  ///
  /// The local-STT arm gets its own, narrower claim rather than reusing
  /// [EntryProcessingCopy.processedOnDevice]. See that constant for why: on
  /// that path nothing has been processed yet and the entry is queued to
  /// upload.
  static String? labelFor(JournalEntry entry) {
    final usedOnnx = entry.processingUsedOnnx;
    if (usedOnnx == true) return EntryProcessingCopy.processedOnDevice;
    if (usedOnnx == false) return EntryProcessingCopy.sentForSecureProcessing;
    if (entry.processingUsedLocalStt == true) {
      return EntryProcessingCopy.transcribedOnDevice;
    }
    return null;
  }

  static Key _keyFor(JournalEntry entry) {
    if (entry.processingUsedOnnx == true) {
      return const Key('entry_processing_on_device_chip');
    }
    if (entry.processingUsedOnnx == false) {
      return const Key('entry_processing_cloud_chip');
    }
    return const Key('entry_processing_transcribed_on_device_chip');
  }

  @override
  Widget build(BuildContext context) {
    final label = labelFor(entry);
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TimelineSyncBadge(key: _keyFor(entry), label: label),
    );
  }
}

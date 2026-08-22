import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Standard correction actions for archive belief / repeat surfaces.
class ArchiveBeliefCorrectionActions extends StatelessWidget {
  const ArchiveBeliefCorrectionActions({
    required this.onNotMe, required this.onCloseButDifferent, required this.onSaveThread, required this.onRecordMoreEvidence, super.key,
    this.compact = false,
  });

  final VoidCallback onNotMe;
  final VoidCallback onCloseButDifferent;
  final VoidCallback onSaveThread;
  final VoidCallback onRecordMoreEvidence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? AppSpacing.xs : AppSpacing.sm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('archive_belief_record_more_evidence'),
          onPressed: onRecordMoreEvidence,
          child: const Text(ArchiveBeliefThreadCopy.recordMoreEvidence),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          key: const Key('archive_belief_save_thread'),
          onPressed: onSaveThread,
          child: const Text(ArchiveBeliefThreadCopy.saveThread),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          key: const Key('archive_belief_close_but_different'),
          onPressed: onCloseButDifferent,
          child: const Text(ArchiveBeliefThreadCopy.closeButDifferent),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          key: const Key('archive_belief_not_me'),
          onPressed: onNotMe,
          child: const Text(ArchiveBeliefThreadCopy.notMe),
        ),
      ],
    );
  }
}
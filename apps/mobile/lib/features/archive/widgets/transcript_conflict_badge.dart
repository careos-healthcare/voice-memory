import 'dart:async';

import 'package:flutter/material.dart';

/// A badge that opens both transcript versions side by side.
class TranscriptConflictBadge extends StatelessWidget {
  const TranscriptConflictBadge({
    required this.deviceA,
    required this.deviceB,
    required this.onResolved,
    super.key,
  });

  final String deviceA;
  final String deviceB;
  final ValueChanged<String> onResolved;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('transcript_conflict_badge'),
      onPressed: () {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => TranscriptConflictDiff(
              deviceA: deviceA,
              deviceB: deviceB,
              onResolved: (text) {
                Navigator.of(context).pop();
                onResolved(text);
              },
            ),
          ),
        );
      },
      child: const Text('Conflict'),
    );
  }
}

/// Side-by-side transcripts with a choice to keep one side or both.
class TranscriptConflictDiff extends StatelessWidget {
  const TranscriptConflictDiff({
    required this.deviceA,
    required this.deviceB,
    required this.onResolved,
    super.key,
  });

  final String deviceA;
  final String deviceB;
  final ValueChanged<String> onResolved;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('transcript_conflict_diff'),
      title: const Text('Conflicting edits'),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(deviceA, key: const Key('transcript_conflict_device_a')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(deviceB, key: const Key('transcript_conflict_device_b')),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('transcript_keep_device_a'),
          onPressed: () => onResolved(deviceA),
          child: const Text('Keep Device A'),
        ),
        TextButton(
          key: const Key('transcript_keep_device_b'),
          onPressed: () => onResolved(deviceB),
          child: const Text('Keep Device B'),
        ),
        TextButton(
          key: const Key('transcript_combine_both'),
          onPressed: () => onResolved('$deviceA\n\n$deviceB'),
          child: const Text('Combine Both'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Both transcript versions, with a choice to keep one.
class TranscriptConflictBadge extends StatelessWidget {
  const TranscriptConflictBadge({
    required this.local,
    required this.remote,
    required this.onKeep,
    super.key,
  });

  final String local;
  final String remote;
  final ValueChanged<String> onKeep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conflict', key: Key('transcript_conflict_badge')),
        Text(local, key: const Key('transcript_conflict_local')),
        TextButton(
          key: const Key('transcript_conflict_keep_local'),
          onPressed: () => onKeep(local),
          child: const Text('Keep this one'),
        ),
        Text(remote, key: const Key('transcript_conflict_remote')),
        TextButton(
          key: const Key('transcript_conflict_keep_remote'),
          onPressed: () => onKeep(remote),
          child: const Text('Keep this one'),
        ),
      ],
    );
  }
}

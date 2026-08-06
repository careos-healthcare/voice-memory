import 'package:flutter/material.dart';

class ArchiveEmptyState extends StatelessWidget {
  const ArchiveEmptyState({super.key, required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('archive_tab_entry_state_empty'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your first saved moment will appear here.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('Record or type something real. You can edit it later.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCapture, child: const Text('Go to Record')),
        ],
      ),
    ),
  );
}

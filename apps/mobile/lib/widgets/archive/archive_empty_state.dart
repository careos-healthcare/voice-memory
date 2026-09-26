import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchiveEmptyState extends StatelessWidget {
  const ArchiveEmptyState({required this.onCapture, super.key});

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
            'Your recordings and typed moments, in your words.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCapture, child: const Text('Record')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/privacy-trust-centre'),
            child: const Text('How it works'),
          ),
        ],
      ),
    ),
  );
}

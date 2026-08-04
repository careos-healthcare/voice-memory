import 'package:flutter/material.dart';

import '../../../comparison_engine/domain/models/archive_moment_record.dart';

class ArchiveMomentsListView extends StatelessWidget {
  const ArchiveMomentsListView({
    super.key,
    required this.moments,
    required this.onMomentTapped,
    required this.onMomentDismissed,
  });

  final List<ArchiveMomentRecord> moments;
  final ValueChanged<ArchiveMomentRecord> onMomentTapped;
  final ValueChanged<ArchiveMomentRecord> onMomentDismissed;

  @override
  Widget build(BuildContext context) {
    if (moments.isEmpty) {
      return const _ArchiveMomentsEmptyState();
    }

    return ListView.builder(
      key: const Key('archive_moments_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: moments.length,
      itemBuilder: (context, index) {
        final moment = moments[index];
        final savedWords = moment.savedWords.trim();
        final title = savedWords.isEmpty ? 'Saved audio moment' : savedWords;

        return Dismissible(
          key: ValueKey('moment_${moment.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsetsDirectional.only(end: 20),
            color: Colors.red.shade900.withValues(alpha: 0.2),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              semanticLabel: 'Delete saved moment',
            ),
          ),
          onDismissed: (_) => onMomentDismissed(moment),
          child: ListTile(
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _formatTimestamp(moment.createdAt),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            onTap: () => onMomentTapped(moment),
          ),
        );
      },
    );
  }

  static String _formatTimestamp(DateTime dateTime) {
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} • '
        '${dateTime.hour}:$minute';
  }
}

class _ArchiveMomentsEmptyState extends StatelessWidget {
  const _ArchiveMomentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('archive_moments_empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              semanticLabel: 'No saved moments',
              size: 48,
              color: Theme.of(context).hintColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No moments saved yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'One sentence is enough. Save a thought whenever something '
              'feels worth capturing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).hintColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

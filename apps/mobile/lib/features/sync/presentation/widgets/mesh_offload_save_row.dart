import 'package:archiveme_mobile/features/sync/mesh_offload_optimistic.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/mesh_offload_skeleton.dart';
import 'package:flutter/material.dart';

/// The saved words stay on screen. A skeleton covers only the settle line.
class MeshOffloadSaveRow extends StatelessWidget {
  const MeshOffloadSaveRow({required this.save, super.key});

  final MeshOffloadOptimisticSave save;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('mesh_offload_save_${save.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            save.preview,
            key: Key('mesh_offload_preview_${save.id}'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          switch (save.phase) {
            MeshOffloadSavePhase.optimistic => Text(
              'Saving',
              key: Key('mesh_offload_optimistic_${save.id}'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            MeshOffloadSavePhase.resolving => MeshOffloadSkeleton(
              entryId: save.id,
            ),
            MeshOffloadSavePhase.settled => Text(
              save.settledLabel ??
                  MeshOffloadOptimisticCoordinator.savedOnDeviceLabel,
              key: Key('mesh_offload_settled_${save.id}'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// Rows for saves the archive list does not yet show as settled cards.
class MeshOffloadOptimisticList extends StatelessWidget {
  const MeshOffloadOptimisticList({required this.saves, super.key});

  final List<MeshOffloadOptimisticSave> saves;

  @override
  Widget build(BuildContext context) {
    if (saves.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final save in saves) MeshOffloadSaveRow(save: save)],
    );
  }
}

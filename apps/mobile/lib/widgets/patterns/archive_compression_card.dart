import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_coordinator.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:archiveme_mobile/features/moments/moment_tag_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Compact prompt to clean up similar moments on the Patterns tab.
class ArchiveCompressionCard extends StatefulWidget {
  const ArchiveCompressionCard({
    required this.group, super.key,
    this.onKept,
    this.onSplit,
    this.onHidden,
    this.onOpenAll,
  });

  final ArchiveMomentGroup group;
  final Future<void> Function(ArchiveMomentGroup group)? onKept;
  final Future<void> Function(ArchiveMomentGroup group)? onSplit;
  final Future<void> Function(ArchiveMomentGroup group)? onHidden;
  final VoidCallback? onOpenAll;

  static const Color warmSurface = Color(0xFFFFFBF5);
  static const Color warmBorder = AppColors.warmBorder;

  @override
  State<ArchiveCompressionCard> createState() => _ArchiveCompressionCardState();
}

class _ArchiveCompressionCardState extends State<ArchiveCompressionCard> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveCompressionShown();
  }

  Future<void> _kept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onKept ?? ArchiveCompressionCoordinator.markKept;
    await handler(widget.group);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _split() async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onSplit ?? ArchiveCompressionCoordinator.markSplit;
    await handler(widget.group);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _hidden() async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onHidden ?? ArchiveCompressionCoordinator.markHidden;
    await handler(widget.group);
    if (mounted) setState(() => _busy = false);
  }

  void _openAll() {
    ActivationTracker.trackArchiveCompressionOpened();
    if (widget.onOpenAll != null) {
      widget.onOpenAll!();
    } else {
      unawaited(context.push('/archive-cleanup'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveCompressionCard.warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArchiveCompressionCard.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clean up your archive',
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ArchiveMe found similar moments.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          _GroupPreview(group: group),
          const SizedBox(height: AppSpacing.md),
          _actionButton(
            label: 'Keep as one pattern',
            onPressed: _busy ? null : _kept,
          ),
          const SizedBox(height: AppSpacing.xs),
          _actionButton(
            label: 'Split this',
            onPressed: _busy ? null : _split,
            outlined: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _hidden,
              child: const Text('Hide group'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openAll,
              child: const Text('See all groups'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(onPressed: onPressed, child: Text(label)),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _GroupPreview extends StatelessWidget {
  const _GroupPreview({required this.group});

  final ArchiveMomentGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArchiveCompressionCard.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${group.count} moments · ${group.dateRangeLabel}',
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13),
          ),
          if (group.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in group.tags.take(4))
                  Chip(
                    label: Text(_tagLabel(tag)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _tagLabel(String id) {
    final tag = momentTagFromId(id);
    return tag?.label ?? id;
  }
}

/// Shared group row used on the full cleanup screen.
class ArchiveCompressionGroupTile extends StatelessWidget {
  const ArchiveCompressionGroupTile({
    required this.group, required this.onKept, required this.onSplit, required this.onHidden, super.key,
    this.busy = false,
  });

  final ArchiveMomentGroup group;
  final VoidCallback onKept;
  final VoidCallback onSplit;
  final VoidCallback onHidden;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveCompressionCard.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArchiveCompressionCard.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupPreview(group: group),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: busy ? null : onKept,
              child: const Text('Keep as one pattern'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: busy ? null : onSplit,
              child: const Text('Split this'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : onHidden,
              child: const Text('Hide group'),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../features/activation/activation_tracker.dart';
import '../features/archive_compression/archive_compression_coordinator.dart';
import '../features/archive_compression/archive_compression_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/patterns/archive_compression_card.dart';

/// Full list of similar-moment groups the user can keep, split, or hide.
class ArchiveCompressionScreen extends StatefulWidget {
  const ArchiveCompressionScreen({
    super.key,
    this.loader,
    this.onKept,
    this.onSplit,
    this.onHidden,
  });

  final Future<List<ArchiveMomentGroup>> Function()? loader;
  final Future<void> Function(ArchiveMomentGroup group)? onKept;
  final Future<void> Function(ArchiveMomentGroup group)? onSplit;
  final Future<void> Function(ArchiveMomentGroup group)? onHidden;

  @override
  State<ArchiveCompressionScreen> createState() =>
      _ArchiveCompressionScreenState();
}

class _ArchiveCompressionScreenState extends State<ArchiveCompressionScreen> {
  List<ArchiveMomentGroup> _groups = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveCompressionOpened();
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loader ?? ArchiveCompressionCoordinator.loadGroups;
    final groups = await loader();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _kept(ArchiveMomentGroup group) async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onKept ?? ArchiveCompressionCoordinator.markKept;
    await handler(group);
    if (!mounted) return;
    await _load();
    setState(() => _busy = false);
  }

  Future<void> _split(ArchiveMomentGroup group) async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onSplit ?? ArchiveCompressionCoordinator.markSplit;
    await handler(group);
    if (!mounted) return;
    await _load();
    setState(() => _busy = false);
  }

  Future<void> _hidden(ArchiveMomentGroup group) async {
    if (_busy) return;
    setState(() => _busy = true);
    final handler = widget.onHidden ?? ArchiveCompressionCoordinator.markHidden;
    await handler(group);
    if (!mounted) return;
    await _load();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Clean up your archive'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      'Group similar moments so your archive stays useful.',
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 15, height: 1.45),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_groups.isEmpty)
                      Text(
                        'Your archive is clean for now.',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      )
                    else
                      for (final group in _groups)
                        ArchiveCompressionGroupTile(
                          group: group,
                          busy: _busy,
                          onKept: () => _kept(group),
                          onSplit: () => _split(group),
                          onHidden: () => _hidden(group),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

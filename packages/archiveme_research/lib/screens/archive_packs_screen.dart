import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_store.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/archive_packs/create_archive_pack_sheet.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

class ArchivePacksScreen extends StatefulWidget {
  const ArchivePacksScreen({super.key, this.store});

  final ArchivePackStore? store;

  @override
  State<ArchivePacksScreen> createState() => _ArchivePacksScreenState();
}

class _ArchivePacksScreenState extends State<ArchivePacksScreen> {
  late final ArchivePackStore _store =
      widget.store ?? ArchivePackStore.instance();
  var _loading = true;
  var _trackedOpen = false;
  List<ArchivePack> _packs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packs = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _packs = packs;
      _loading = false;
    });
    if (!_trackedOpen) {
      _trackedOpen = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archivePacksOpened,
        source: 'settings',
        packCountBucket: ActivationFunnelAnalytics.resultCountBucket(
          packs.length,
        ),
        oncePerSession: true,
      );
    }
  }

  Future<void> _create() async {
    final name = await showCreateArchivePackSheet(context);
    if (name == null || name.trim().isEmpty) return;
    await _store.create(name.trim());
    await _load();
  }

  void _open(ArchivePack pack) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePackOpened,
      entryCount: pack.entryIds.length,
      source: 'packs_list',
    );
    context.push('/archive-packs/${pack.id}').then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ArchivePacksCopy.screenTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  ArchivePacksCopy.intro,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ArchivePacksCopy.memoryBoundaryLine,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_packs.isEmpty)
                  Text(
                    '${ArchivePacksCopy.emptyTitle}. ${ArchivePacksCopy.emptyHelper}',
                    key: const Key('archive_packs_empty'),
                  )
                else
                  for (final pack in _packs) ...[
                    ListTile(
                      key: Key('archive_pack_tile_${pack.id}'),
                      title: Text(pack.name),
                      subtitle: Text('${pack.entryIds.length} entries'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(pack),
                    ),
                    const Divider(height: 1),
                  ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('create_archive_pack_list_button'),
                    onPressed: _create,
                    child: Text(ArchivePacksCopy.createPack),
                  ),
                ),
              ],
            ),
    );
  }
}

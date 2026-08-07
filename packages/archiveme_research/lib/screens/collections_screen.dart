import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/collections/archive_collection.dart';
import 'package:voicememory_mobile/features/collections/archive_collection_store.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/collections/collection_card.dart';
import 'package:voicememory_mobile/widgets/collections/create_collection_sheet.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Collections — user-created groups of entries. Organization only:
/// nothing here reads or writes memory state.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key, this.store});

  /// Injectable for tests; defaults to the app prefs store.
  final ArchiveCollectionStore? store;

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  late final ArchiveCollectionStore _store =
      widget.store ?? ArchiveCollectionStore.instance();
  var _loading = true;
  var _trackedOpen = false;
  List<ArchiveCollection> _collections = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collections = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _loading = false;
    });
    if (!_trackedOpen) {
      _trackedOpen = true;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionsOpened,
        collectionCountBucket: ActivationFunnelAnalytics.resultCountBucket(
          collections.length,
        ),
        oncePerSession: true,
      );
    }
  }

  Future<void> _create() async {
    final created = await showCreateCollectionSheet(context, store: _store);
    if (created != null) await _load();
  }

  void _open(ArchiveCollection collection) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.collectionOpened,
      entryCount: collection.entryIds.length,
    );
    context.push('/collections/${collection.id}').then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ArchiveCollectionsCopy.screenTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  ArchiveCollectionsCopy.intro,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_collections.isEmpty)
                  _empty(context)
                else
                  for (final collection in _collections) ...[
                    CollectionCard(
                      collection: collection,
                      onTap: () => _open(collection),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('collections_create_button'),
                    onPressed: _create,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(ArchiveCollectionsCopy.createCollection),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      key: const Key('collections_empty_state'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            ArchiveCollectionsCopy.emptyTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveCollectionsCopy.emptyHelper,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

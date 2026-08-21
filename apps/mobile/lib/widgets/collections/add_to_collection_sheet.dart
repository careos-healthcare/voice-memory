import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/collections/archive_collection.dart';
import 'package:archiveme_mobile/features/collections/archive_collection_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/collections/create_collection_sheet.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Bottom sheet to add or remove one entry from collections.
///
/// Organization only: toggling membership writes group lists in the
/// collection store and never touches the entry, memory records, or
/// scope. Analytics carries counts and a stable source id — never the
/// collection name or any entry text.
Future<void> showAddToCollectionSheet(
  BuildContext context, {
  required ArchiveCollectionStore store,
  required String entryId,
  String source = 'entry_detail',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        AddToCollectionSheet(store: store, entryId: entryId, source: source),
  );
}

class AddToCollectionSheet extends StatefulWidget {
  const AddToCollectionSheet({
    required this.store, required this.entryId, super.key,
    this.source = 'entry_detail',
  });

  final ArchiveCollectionStore store;
  final String entryId;

  /// Stable analytics source id only.
  final String source;

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  var _loading = true;
  List<ArchiveCollection> _collections = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final collections = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _loading = false;
    });
  }

  Future<void> _toggle(ArchiveCollection collection) async {
    final isMember = collection.contains(widget.entryId);
    if (isMember) {
      await widget.store.removeEntry(collection.id, widget.entryId);
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionEntryRemoved,
        source: widget.source,
      );
    } else {
      await widget.store.addEntry(collection.id, widget.entryId);
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionEntryAdded,
        source: widget.source,
      );
    }
    await _load();
  }

  Future<void> _createAndAdd() async {
    final created = await showCreateCollectionSheet(
      context,
      store: widget.store,
      source: widget.source,
    );
    if (created == null) return;
    await widget.store.addEntry(created.id, widget.entryId);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.collectionEntryAdded,
      source: widget.source,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ArchiveCollectionsCopy.addToCollection,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_collections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  ArchiveCollectionsCopy.emptyHelper,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final collection in _collections)
                      CheckboxListTile(
                        key: Key('add_to_collection_${collection.id}'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ArchiveMobileTypography.listTitle(context),
                        ),
                        value: collection.contains(widget.entryId),
                        onChanged: (_) => _toggle(collection),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('add_to_collection_new'),
                onPressed: _createAndAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(ArchiveCollectionsCopy.newCollection),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
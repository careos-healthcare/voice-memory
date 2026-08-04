import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/collections/archive_collection.dart';
import '../../features/collections/archive_collection_store.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_spacing.dart';

/// Bottom sheet for creating a collection. The typed name goes to the
/// local store only — never to analytics or logs.
Future<ArchiveCollection?> showCreateCollectionSheet(
  BuildContext context, {
  required ArchiveCollectionStore store,
  String source = 'collections',
}) {
  return showModalBottomSheet<ArchiveCollection?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => CreateCollectionSheet(store: store, source: source),
  );
}

class CreateCollectionSheet extends StatefulWidget {
  const CreateCollectionSheet({
    super.key,
    required this.store,
    this.source = 'collections',
  });

  final ArchiveCollectionStore store;

  /// Stable analytics source id only.
  final String source;

  @override
  State<CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<CreateCollectionSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final created = await widget.store.create(_controller.text);
      if (created == null) return;
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.collectionCreated,
        source: widget.source,
      );
      if (mounted) Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveCollectionsCopy.newCollection,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('collection_name_field'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              labelText: ArchiveCollectionsCopy.nameLabel,
              hintText: ArchiveCollectionsCopy.namePlaceholders.first,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('create_collection_button'),
              onPressed: _busy ? null : _create,
              child: Text(ArchiveCollectionsCopy.createCollection),
            ),
          ),
        ],
      ),
    );
  }
}

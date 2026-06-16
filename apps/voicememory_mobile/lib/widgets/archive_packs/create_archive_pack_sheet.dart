import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../theme/app_spacing.dart';

/// Returns the typed pack name only — never logs it. Caller creates the pack.
Future<String?> showCreateArchivePackSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const CreateArchivePackSheet(),
  );
}

class CreateArchivePackSheet extends StatefulWidget {
  const CreateArchivePackSheet({super.key});

  @override
  State<CreateArchivePackSheet> createState() => _CreateArchivePackSheetState();
}

class _CreateArchivePackSheetState extends State<CreateArchivePackSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
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
            ArchivePacksCopy.newPack,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('archive_pack_name_field'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: ArchivePacksCopy.packName,
              hintText: ArchivePacksCopy.exampleNames.first,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('create_archive_pack_button'),
              onPressed: _submit,
              child: Text(ArchivePacksCopy.createPack),
            ),
          ),
        ],
      ),
    );
  }
}

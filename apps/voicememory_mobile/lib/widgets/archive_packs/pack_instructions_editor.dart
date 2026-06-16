import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../features/archive_packs/archive_pack_store.dart';
import '../../theme/app_spacing.dart';

/// Edits pack instructions — local only, never logged.
class PackInstructionsEditor extends StatefulWidget {
  const PackInstructionsEditor({
    super.key,
    required this.packId,
    this.store,
    this.initialInstructions = '',
    this.onSaved,
  });

  final String packId;
  final ArchivePackStore? store;
  final String initialInstructions;
  final VoidCallback? onSaved;

  @override
  State<PackInstructionsEditor> createState() => _PackInstructionsEditorState();
}

class _PackInstructionsEditorState extends State<PackInstructionsEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialInstructions,
  );
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final store = widget.store ?? ArchivePackStore.instance();
      await store.saveInstructions(widget.packId, _controller.text);
      widget.onSaved?.call();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pack_instructions_editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchivePacksCopy.packInstructions,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 4),
        Text(
          ArchivePacksCopy.packInstructionsHelper,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('pack_instructions_field'),
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const Key('pack_instructions_save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

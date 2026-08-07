import 'package:flutter/material.dart';

import '../../features/activation/capture_context_tags.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_spacing.dart';

/// Result from the manual context tag editor sheet.
enum EditContextTagAction { cancel, clear, save }

class EditContextTagResult {
  const EditContextTagResult({required this.action, this.tagId});

  final EditContextTagAction action;
  final String? tagId;
}

/// Shows a local tag picker for editing an existing saved entry.
Future<EditContextTagResult?> showEditContextTagSheet(
  BuildContext context, {
  required String? initialTagId,
}) {
  return showModalBottomSheet<EditContextTagResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => EditContextTagSheet(initialTagId: initialTagId),
  );
}

/// Tag picker sheet content for editing an existing saved entry.
class EditContextTagSheet extends StatefulWidget {
  const EditContextTagSheet({super.key, required this.initialTagId});

  final String? initialTagId;

  @override
  State<EditContextTagSheet> createState() => _EditContextTagSheetState();
}

class _EditContextTagSheetState extends State<EditContextTagSheet> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialTagId;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              VisibleArchiveProofCopy.entryContextTagEditTitle,
              key: const Key('edit_context_tag_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              VisibleArchiveProofCopy.captureContextTagHelper,
              key: const Key('edit_context_tag_helper'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in CaptureContextTags.all)
                  ChoiceChip(
                    key: Key('edit_context_tag_${tag.id}'),
                    label: Text(tag.label),
                    selected: _selectedId == tag.id,
                    onSelected: (selected) =>
                        setState(() => _selectedId = selected ? tag.id : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  key: const Key('edit_context_tag_cancel'),
                  onPressed: () => Navigator.of(context).pop(
                    const EditContextTagResult(
                      action: EditContextTagAction.cancel,
                    ),
                  ),
                  child: Text(VisibleArchiveProofCopy.entryContextTagCancel),
                ),
                if (widget.initialTagId != null)
                  TextButton(
                    key: const Key('edit_context_tag_clear'),
                    onPressed: () => Navigator.of(context).pop(
                      const EditContextTagResult(
                        action: EditContextTagAction.clear,
                      ),
                    ),
                    child: Text(VisibleArchiveProofCopy.entryContextTagClear),
                  ),
                FilledButton(
                  key: const Key('edit_context_tag_save'),
                  onPressed: _selectedId == null
                      ? null
                      : () => Navigator.of(context).pop(
                          EditContextTagResult(
                            action: EditContextTagAction.save,
                            tagId: _selectedId,
                          ),
                        ),
                  child: Text(VisibleArchiveProofCopy.captureContextTagSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

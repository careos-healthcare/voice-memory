import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/action_items/action_item_store.dart';
import '../../features/action_items/archive_action_item.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_spacing.dart';
import '../memory/preserve_original_control.dart';

/// Editor for creating or updating one action item.
///
/// Pre-fills a safe short title only — never long private text unless
/// the user types it here. Optional due date is stored locally only.
Future<bool> showActionItemEditorSheet(
  BuildContext context, {
  required ActionItemStore store,
  ArchiveActionItem? existing,
  JournalEntry? entry,
  String? prefillTitle,
  String source = 'remember_this',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (context) => ActionItemEditorSheet(
      store: store,
      existing: existing,
      entry: entry,
      prefillTitle: prefillTitle,
      source: source,
    ),
  ).then((value) => value ?? false);
}

class ActionItemEditorSheet extends StatefulWidget {
  const ActionItemEditorSheet({
    super.key,
    required this.store,
    this.existing,
    this.entry,
    this.prefillTitle,
    this.source = 'remember_this',
  });

  final ActionItemStore store;
  final ArchiveActionItem? existing;
  final JournalEntry? entry;
  final String? prefillTitle;
  final String source;

  @override
  State<ActionItemEditorSheet> createState() => _ActionItemEditorSheetState();
}

class _ActionItemEditorSheetState extends State<ActionItemEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  DateTime? _dueAt;
  var _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final safeTitle =
        existing?.title ??
        widget.prefillTitle ??
        (widget.entry != null ? timelineEntryTitle(widget.entry!) : '');
    _titleController = TextEditingController(text: safeTitle);
    _noteController = TextEditingController(text: existing?.note ?? '');
    _dueAt = existing?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: ActionItemsCopy.chooseDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _dueAt = picked);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(ActionItemsCopy.reminderSaved),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_editing) {
        await widget.store.update(
          id: widget.existing!.id,
          title: title,
          note: _noteController.text,
          dueAt: () => _dueAt,
          clearDueAt: _dueAt == null,
        );
      } else {
        final entry = widget.entry;
        await widget.store.create(
          sourceEntryId: entry?.id ?? widget.existing?.sourceEntryId ?? '',
          title: title,
          note: _noteController.text,
          dueAt: _dueAt,
          archivePackId: entry?.archivePackId,
          archiveThreadId: entry?.archiveThreadId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
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
              _editing ? ActionItemsCopy.edit : ActionItemsCopy.rememberThis,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('action_item_title_field'),
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: ActionItemsCopy.titleLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('action_item_note_field'),
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: ActionItemsCopy.noteLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('action_item_due_date_button'),
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _dueAt == null
                    ? ActionItemsCopy.addReminder
                    : ActionItemsCopy.dueDateLabel,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.entry != null)
              PreserveOriginalEditor(entry: widget.entry!, onChanged: () {}),
            if (widget.entry != null) const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const Key('action_item_save_button'),
                onPressed: _busy ? null : _save,
                child: Text(ActionItemsCopy.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

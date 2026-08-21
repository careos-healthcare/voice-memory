import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/edit_context_tag_sheet.dart';
import 'package:flutter/material.dart';

/// Shows the current context tag and lets users edit it later.
class EntryContextTagEditor extends StatelessWidget {
  const EntryContextTagEditor({
    required this.entry, required this.journalStore, required this.onChanged, super.key,
  });

  final JournalEntry entry;
  final JournalStore journalStore;
  final VoidCallback onChanged;

  String get _statusLine {
    final label = CaptureContextTags.labelForEntry(entry);
    if (label == null) return VisibleArchiveProofCopy.entryContextTagNone;
    return VisibleArchiveProofCopy.entryContextTagPresent(label);
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showEditContextTagSheet(
      context,
      initialTagId: entry.captureContextTag,
    );
    if (result == null || result.action == EditContextTagAction.cancel) {
      return;
    }

    final nextTagId = switch (result.action) {
      EditContextTagAction.cancel => entry.captureContextTag,
      EditContextTagAction.clear => null,
      EditContextTagAction.save => result.tagId,
    };
    await journalStore.updateCaptureContextTag(entry.id, tagId: nextTagId);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('entry_context_tag_editor'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLine,
            key: const Key('entry_context_tag_status'),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('entry_context_tag_edit_button'),
            onPressed: () => _edit(context),
            child: const Text(VisibleArchiveProofCopy.entryContextTagEdit),
          ),
        ],
      ),
    );
  }
}
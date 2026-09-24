import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_materializer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/controllers/entry_controller.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/actionable_empty_state.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/archive_template_gallery.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hosts [ActionableEmptyState] with a caller-supplied draft writer.
///
/// The journal feature directory is a retired symlink, so blank-entry imports
/// live here and mount onto the typed-capture screen.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.controller,
    super.key,
    this.onDraftCreated,
    this.onOpenTemplate,
    this.onViewTemplateEvidence,
    this.compact = false,
  });

  final EntryController controller;
  final ValueChanged<JournalEntry>? onDraftCreated;

  /// Saves the template, then the host opens its page in the editor.
  final Future<void> Function(ArchiveEntryTemplate template)? onOpenTemplate;

  final void Function(ArchiveTemplateDraft draft)? onViewTemplateEvidence;

  /// Title and chips only, for the short focused capture card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        entryControllerProvider.overrideWithValue(controller),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionableEmptyState(
            onDraftCreated: onDraftCreated,
            compact: compact,
          ),
          if (!compact && onOpenTemplate != null) ...[
            const SizedBox(height: 16),
            ArchiveTemplateGallery(
              onOpenTemplate: onOpenTemplate!,
              onViewEvidence: onViewTemplateEvidence,
            ),
          ],
        ],
      ),
    );
  }
}

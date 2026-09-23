import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_service.dart';
import 'package:archiveme_mobile/features/metadata/entry_metadata_views.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/entry_sync_indicator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ArchiveEntryCard extends StatelessWidget {
  const ArchiveEntryCard({
    required this.entry,
    required this.onTap,
    super.key,
    this.onMoveToPrivateVault,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onMoveToPrivateVault;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticsLabel,
      hint: 'Opens the original saved moment',
      child: Hero(
        tag: ArchiveEntryHeroTags.surface(entry.id),
        child: Material(
          color: Colors.transparent,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ArchiveEntryCardMeta(entry: entry),
                      const SizedBox(height: 10),
                      ArchiveEntryCardPreview(entry: entry),
                      TextButton(
                        key: const Key('move_to_private_vault'),
                        onPressed: onMoveToPrivateVault,
                        child: const Text('Move to Private Vault'),
                      ),
                      EntryCardTile(
                        transcript: entry.transcript,
                        metadata: AmbientMetadataService.shared.metadataFor(
                          entry.id,
                        ),
                        showTranscript: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _semanticsLabel {
    final source = entry.durationSeconds > 0 ? 'Voice' : 'Text';
    final date = DateFormat.yMMMMd()
        .add_jm()
        .format(entry.createdAt.toLocal());
    return '$source saved moment from $date';
  }
}

class ArchiveEntryCardMeta extends StatelessWidget {
  const ArchiveEntryCardMeta({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = entry.durationSeconds > 0 ? 'Voice' : 'Text';
    final date = DateFormat.yMMMMd()
        .add_jm()
        .format(entry.createdAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          source,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        EntrySyncIndicator(status: entry.syncStatus),
      ],
    );
  }
}

class ArchiveEntryCardPreview extends StatelessWidget {
  const ArchiveEntryCardPreview({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = entry.transcript.trim();

    return Text(
      text.isEmpty ? 'Transcript processing…' : text,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge,
    );
  }
}

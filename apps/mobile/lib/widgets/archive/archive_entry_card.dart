import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ArchiveEntryCard extends StatelessWidget {
  const ArchiveEntryCard({required this.entry, required this.onTap, super.key});

  final JournalEntry entry;
  final VoidCallback onTap;

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
                      if (_hasPlayableAudio(entry)) ...[
                        EntryAudioPlayer(
                          audioPath: entry.localAudioPath,
                          durationSeconds: entry.durationSeconds,
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 10),
                      ArchiveEntryCardPreview(entry: entry),
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

  static bool _hasPlayableAudio(JournalEntry entry) =>
      entry.durationSeconds > 0 &&
      (entry.localAudioPath?.trim().isNotEmpty ?? false);

  String get _semanticsLabel {
    final source = entry.durationSeconds > 0 ? 'Voice' : 'Typed';
    final date = DateFormat.yMMMMd().add_jm().format(entry.createdAt.toLocal());
    return '$source saved moment from $date';
  }
}

class ArchiveEntryCardMeta extends StatelessWidget {
  const ArchiveEntryCardMeta({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voice = entry.durationSeconds > 0;
    final date = DateFormat.yMMMMd().add_jm().format(entry.createdAt.toLocal());
    final minutes = entry.durationSeconds ~/ 60;
    final seconds = entry.durationSeconds % 60;
    final duration = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              voice ? Icons.mic_none_rounded : Icons.edit_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              voice ? 'Voice' : 'Typed',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (voice) ...[
              const SizedBox(width: 8),
              Text(
                duration,
                key: Key('archive_entry_duration_${entry.id}'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ArchiveEntryCardPreview extends StatelessWidget {
  const ArchiveEntryCardPreview({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = entry.transcript.trim();

    final pending = text.isEmpty;
    return Text(
      pending ? 'Transcript processing…' : text,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: pending
          ? ArchiveMobileTypography.uiBody(context)
          : ArchiveMobileTypography.userWords(context),
    );
  }
}

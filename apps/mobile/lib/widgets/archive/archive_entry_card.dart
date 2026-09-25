import 'dart:io';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_entry_hero_tags.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/entry/entry_audio_player.dart';
import 'package:flutter/material.dart';

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArchiveEntryCardPreview(entry: entry),
                            const SizedBox(height: 10),
                            ArchiveEntryCardMeta(entry: entry),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (entry.durationSeconds > 0 ||
                    (entry.localAudioPath?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: EntryAudioPlayer(
                      audioPath: entry.localAudioPath,
                      durationSeconds: entry.durationSeconds,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _semanticsLabel {
    final source = entry.durationSeconds > 0 ? 'Voice' : 'Typed';
    return '$source saved moment';
  }
}

class ArchiveEntryCardMeta extends StatelessWidget {
  const ArchiveEntryCardMeta({required this.entry, super.key});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voice = entry.durationSeconds > 0;
    final time = LocaleDateFormat.time(context, entry.createdAt);
    final minutes = entry.durationSeconds ~/ 60;
    final seconds = entry.durationSeconds % 60;
    final duration = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          voice ? '$time · $duration' : time,
          key: voice ? Key('archive_entry_duration_${entry.id}') : null,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
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
          ],
        ),
        if ((entry.captureSource ?? '') == 'apple_voice_memo')
          Text(
            'Voice memo',
            key: Key('archive_voice_memo_${entry.id}'),
          ),
        if ((entry.reflection.healthStateOfMind ?? '').isNotEmpty)
          Text(
            'State of Mind · ${entry.reflection.healthStateOfMind}',
            key: Key('archive_state_of_mind_${entry.id}'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              key: Key('archive_entry_images_${entry.id}'),
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final path in entry.images)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _EntryPhoto(path: path),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Text(
      pending ? 'Transcript processing…' : text,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: pending
          ? ArchiveMobileTypography.uiBody(context)
          : ArchiveMobileTypography.userWords(context),
      ),
      ],
    );
  }
}

class _EntryPhoto extends StatelessWidget {
  const _EntryPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final broken = const SizedBox(
      width: 72,
      child: Icon(Icons.broken_image_outlined),
    );
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => broken,
      );
    }
    return Image.file(
      File(path),
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => broken,
    );
  }
}

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter/material.dart';

/// Both transcripts when two devices edited the words at the same time.
class TranscriptSplit {
  const TranscriptSplit({
    required this.localText,
    required this.remoteText,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
  });

  final String localText;
  final String remoteText;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
}

/// Metadata from the later edit, plus both transcripts when they diverged.
class EntryConflictResult {
  const EntryConflictResult({required this.entry, this.transcripts});

  final JournalEntry entry;
  final TranscriptSplit? transcripts;

  bool get transcriptDiverged => transcripts != null;
}

/// Holds an open transcript choice until the person picks a version.
abstract final class TranscriptConflictStore {
  TranscriptConflictStore._();

  static final _open = <String, TranscriptSplit>{};

  static void remember(String entryId, TranscriptSplit split) {
    _open[entryId] = split;
  }

  static TranscriptSplit? read(String entryId) => _open[entryId];

  static void clear(String entryId) => _open.remove(entryId);
}

extension JournalEntryConflict on JournalEntry {
  /// True while two devices still have unmerged transcript edits.
  bool get hasConflict =>
      syncStatus == SyncStatus.conflict ||
      TranscriptConflictStore.read(id) != null;
}

/// Last-writer-wins for date, title, mood, and tags.
///
/// A transcript edited on both sides is kept as two versions.
abstract final class EntryConflictResolver {
  EntryConflictResolver._();

  static EntryConflictResult merge({
    required JournalEntry local,
    required JournalEntry remote,
  }) {
    final remoteWins = remote.updatedAt.isAfter(local.updatedAt);
    final meta = remoteWins ? remote : local;
    final localText = local.transcript.trim();
    final remoteText = remote.transcript.trim();
    final diverged = localText != remoteText;
    final merged = local.copyWith(
      createdAt: meta.createdAt,
      updatedAt: remoteWins ? remote.updatedAt : local.updatedAt,
      syncStatus: diverged ? SyncStatus.conflict : local.syncStatus,
      reflection: Reflection(
        mood: meta.reflection.mood,
        emotionalIntensity: local.reflection.emotionalIntensity,
        recurringThemes: meta.reflection.recurringThemes,
        exactLanguagePattern: local.reflection.exactLanguagePattern,
        concreteObservation: local.reflection.concreteObservation,
        repeatedSignal: local.reflection.repeatedSignal,
        tensionOrContradiction: local.reflection.tensionOrContradiction,
        avoidedOrVagueArea: local.reflection.avoidedOrVagueArea,
        nextSmallAction: local.reflection.nextSmallAction,
        patternObservations: local.reflection.patternObservations,
        healthStateOfMind: local.reflection.healthStateOfMind,
      ),
      display: local.display.copyWith(
        title: meta.display.title,
        captureContextTag: meta.captureContextTag,
      ),
    );
    final split = diverged
        ? TranscriptSplit(
            localText: local.transcript,
            remoteText: remote.transcript,
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: remote.updatedAt,
          )
        : null;
    if (split != null) TranscriptConflictStore.remember(local.id, split);
    return EntryConflictResult(entry: merged, transcripts: split);
  }
}

/// Asks which transcript to keep when both devices edited the words.
class TranscriptConflictPrompt extends StatelessWidget {
  const TranscriptConflictPrompt({
    required this.split,
    required this.onKeep,
    super.key,
  });

  static const message = 'Conflicting edits detected. Choose version to keep.';

  final TranscriptSplit split;
  final ValueChanged<String> onKeep;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('transcript_conflict_prompt'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 8),
        Text(split.localText, key: const Key('transcript_conflict_local')),
        TextButton(
          key: const Key('transcript_keep_local'),
          onPressed: () => onKeep(split.localText),
          child: const Text('Keep this phone'),
        ),
        Text(split.remoteText, key: const Key('transcript_conflict_remote')),
        TextButton(
          key: const Key('transcript_keep_remote'),
          onPressed: () => onKeep(split.remoteText),
          child: const Text('Keep the other phone'),
        ),
      ],
    );
  }
}

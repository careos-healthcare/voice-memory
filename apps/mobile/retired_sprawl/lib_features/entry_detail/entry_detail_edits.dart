import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Writes a new [createdAt] and bumps the entry revision.
Future<void> saveEntryCreatedAt({
  required JournalStore store,
  required JournalEntry entry,
  required DateTime createdAt,
}) {
  return store.saveEdit(entry.copyWith(createdAt: createdAt));
}

/// Writes an optional title onto display metadata and bumps the revision.
Future<void> saveEntryTitle({
  required JournalStore store,
  required JournalEntry entry,
  required String title,
}) {
  final trimmed = title.trim();
  return store.saveEdit(
    entry.copyWith(
      display: entry.display.copyWith(
        title: trimmed.isEmpty ? null : trimmed,
      ),
    ),
  );
}

/// Writes a place name onto display metadata.
Future<void> saveEntryPlace({
  required JournalStore store,
  required JournalEntry entry,
  required String place,
}) {
  final trimmed = place.trim();
  return store.saveEdit(
    entry.copyWith(
      display: entry.display.copyWith(
        locationLabel: trimmed.isEmpty ? null : trimmed,
      ),
    ),
  );
}

/// Writes a state-of-mind label onto the entry reflection.
Future<void> saveEntryMood({
  required JournalStore store,
  required JournalEntry entry,
  required String mood,
}) {
  final current = entry.reflection;
  return store.saveEdit(
    entry.copyWith(
      reflection: Reflection(
        mood: mood.trim(),
        emotionalIntensity: current.emotionalIntensity,
        recurringThemes: current.recurringThemes,
        exactLanguagePattern: current.exactLanguagePattern,
        concreteObservation: current.concreteObservation,
        repeatedSignal: current.repeatedSignal,
        tensionOrContradiction: current.tensionOrContradiction,
        avoidedOrVagueArea: current.avoidedOrVagueArea,
        nextSmallAction: current.nextSmallAction,
        patternObservations: current.patternObservations,
      ),
    ),
  );
}

/// Newest first, matching the archive query `created_at DESC, id DESC`.
List<JournalEntry> archiveOrder(Iterable<JournalEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
  return sorted;
}

import 'package:archiveme_mobile/features/health/state_of_mind_writer.dart';
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
///
/// The person's own mood stays as they chose it. A Health badge, when one
/// is already stored, is left beside it. On iOS, the write setting can also
/// save this mood to Apple Health.
Future<void> saveEntryMood({
  required JournalStore store,
  required JournalEntry entry,
  required String mood,
}) async {
  final current = entry.reflection;
  final chosen = mood.trim();
  await store.saveEdit(
    entry.copyWith(
      reflection: Reflection(
        mood: chosen,
        emotionalIntensity: current.emotionalIntensity,
        recurringThemes: current.recurringThemes,
        exactLanguagePattern: current.exactLanguagePattern,
        concreteObservation: current.concreteObservation,
        repeatedSignal: current.repeatedSignal,
        tensionOrContradiction: current.tensionOrContradiction,
        avoidedOrVagueArea: current.avoidedOrVagueArea,
        nextSmallAction: current.nextSmallAction,
        patternObservations: current.patternObservations,
        healthStateOfMind: current.healthStateOfMind,
      ),
    ),
  );
  await StateOfMindWriter.writeJournalMood(chosen, entryId: entry.id);
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

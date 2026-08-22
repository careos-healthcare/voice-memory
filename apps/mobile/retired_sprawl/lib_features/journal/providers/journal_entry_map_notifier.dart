import 'package:archiveme_mobile/features/journal/providers/journal_entity_slices.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Normalized journal-entry map independent of timeline ordering.
final class JournalEntryMapNotifier extends AsyncNotifier<JournalEntryMapState> {
  @override
  Future<JournalEntryMapState> build() async {
    ref.keepAlive();
    return const JournalEntryMapState.empty();
  }

  void mergeParsed(Map<String, JournalEntry> entries) {
    if (entries.isEmpty) return;
    final current = state.value ?? const JournalEntryMapState.empty();
    state = AsyncData(current.putAll(entries));
  }

  void upsert(JournalEntry entry) {
    final current = state.value ?? const JournalEntryMapState.empty();
    state = AsyncData(current.putEntry(entry));
  }

  void remove(String entryId) {
    final current = state.value ?? const JournalEntryMapState.empty();
    state = AsyncData(current.removeEntry(entryId));
  }
}

final journalEntryMapProvider =
    AsyncNotifierProvider<JournalEntryMapNotifier, JournalEntryMapState>(
  JournalEntryMapNotifier.new,
);

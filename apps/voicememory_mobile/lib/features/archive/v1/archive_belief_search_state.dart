import '../../../models/journal_entry.dart';

/// V1 substring search over saved moment transcripts.
class ArchiveBeliefSearchState {
  String query = '';

  bool get isActive => query.isNotEmpty;

  void updateQuery(String value) {
    query = value;
  }

  List<JournalEntry> filter(List<JournalEntry> entries) {
    if (query.isEmpty) return entries;
    final needle = query.toLowerCase();
    return entries
        .where((entry) => entry.transcript.toLowerCase().contains(needle))
        .toList();
  }
}

import '../../models/journal_entry.dart';
import 'early_first_signal_engine.dart';

/// Entry-count and proof gates for the tomorrow-return reminder card.
abstract final class EarlyArchiveReturnReminderGates {
  EarlyArchiveReturnReminderGates._();

  /// True once the user has a confirmed repeat or a real early evidence timeline.
  static bool eligible({
    required int entryCount,
    required List<JournalEntry> entries,
    required bool hasRealTimeline,
  }) {
    if (entryCount < 3) return false;
    if (hasRealTimeline) return true;
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
  }
}

import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Entry-count and proof gates for the tomorrow-return reminder card.
abstract final class EarlyArchiveReturnReminderGates {
  EarlyArchiveReturnReminderGates._();

  /// True once the user has a confirmed repeat or a real early evidence timeline.
  static bool eligible({
    required int entryCount,
    required List<JournalEntry> entries,
    required bool hasRealTimeline,
  }) {
    if (entryCount <= 1) return false;
    if (entryCount < 3) return false;
    if (hasRealTimeline) return true;
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
  }
}
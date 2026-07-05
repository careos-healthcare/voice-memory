import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import 'chat_differentiation_copy.dart';
import 'chat_differentiation_model.dart';

/// Builds timeline rows from saved moments — dates only, no transcript text.
abstract final class ChatDifferentiationEngine {
  ChatDifferentiationEngine._();

  static List<ChatDifferentiationTimelineRow> timelineFromEntries(
    List<JournalEntry> entries,
  ) {
    if (entries.isEmpty) return const [];

    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    const labels = [
      ChatDifferentiationCopy.timelineFirstSavedLabel,
      ChatDifferentiationCopy.timelineCameBackLabel,
      ChatDifferentiationCopy.timelineRepeatedAgainLabel,
    ];
    const fallbacks = [
      ChatDifferentiationCopy.timelineEarlierFallback,
      ChatDifferentiationCopy.timelineLaterFallback,
      ChatDifferentiationCopy.timelineAgainFallback,
    ];

    final rows = <ChatDifferentiationTimelineRow>[];
    for (var i = 0; i < sorted.length && i < labels.length; i++) {
      rows.add(
        ChatDifferentiationTimelineRow(
          label: labels[i],
          dateLabel: _shortDateLabel(sorted[i].createdAt) ?? fallbacks[i],
        ),
      );
    }
    return rows;
  }

  static String? _shortDateLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final date = formatUserFacingDate(createdAt).trim();
    if (date.isEmpty) return null;
    return '$date · $displayHour:$minute $period';
  }
}

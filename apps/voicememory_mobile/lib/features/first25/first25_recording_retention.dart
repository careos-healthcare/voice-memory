import '../../models/journal_entry.dart';
import '../../services/app_services.dart';

/// Persists cohort anchor + one-time D1/D3/D7 recording milestones.
abstract final class First25RecordingRetention {
  First25RecordingRetention._();

  static const String _prefsKey = 'first25RecordingRetention';

  static bool isEligibleRecording(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    return transcript.isNotEmpty && !transcript.startsWith('[draft]');
  }

  /// Returns newly fired cohort days (1, 3, 7) for this save.
  static Future<List<int>> recordEligibleRecording({
    required DateTime createdAt,
  }) async {
    try {
      final prefs = AppServices.instance.prefs;
      final state = await prefs.readMap(_prefsKey) ?? {};
      final anchorRaw = state['firstRecordingAt'] as String?;
      final fired = _readFiredDays(state);

      final anchor = anchorRaw != null
          ? DateTime.tryParse(anchorRaw)
          : null;
      if (anchor == null) {
        await prefs.writeMap(_prefsKey, {
          'firstRecordingAt': createdAt.toUtc().toIso8601String(),
          'firedDays': fired,
        });
        return const [];
      }

      final daysSince = _calendarDaysSince(anchor.toUtc(), createdAt.toUtc());
      final out = <int>[];
      for (final day in const [1, 3, 7]) {
        if (daysSince >= day && !fired.contains(day)) {
          fired.add(day);
          out.add(day);
        }
      }
      if (out.isNotEmpty) {
        await prefs.writeMap(_prefsKey, {
          'firstRecordingAt': anchor.toUtc().toIso8601String(),
          'firedDays': fired,
        });
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static List<int> _readFiredDays(Map<String, dynamic> state) {
    final raw = state['firedDays'];
    if (raw is! List) return [];
    return raw
        .map((e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .toList();
  }

  static int _calendarDaysSince(DateTime anchor, DateTime at) {
    final a = DateTime.utc(anchor.year, anchor.month, anchor.day);
    final b = DateTime.utc(at.year, at.month, at.day);
    return b.difference(a).inDays;
  }
}

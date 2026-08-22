import 'package:archiveme_mobile/product/consumer_copy_guard.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Answers that drive the return loop after recording.
class TomorrowReturnLoop {
  const TomorrowReturnLoop({
    required this.noticedToday,
    required this.comeBackTomorrow,
    required this.watchForNextTime,
    required this.generatedAt,
    this.watchForChips = const [],
    this.tomorrowPrompt = '',
  });

  final String noticedToday;
  final String comeBackTomorrow;
  final String watchForNextTime;
  final DateTime generatedAt;
  final List<String> watchForChips;
  final String tomorrowPrompt;

  /// Theme-derived chips only — no generic filler chips.
  List<String> get displayWatchChips =>
      ConsumerCopyGuard.userFacingChips(watchForChips).take(3).toList();

  String get displayTomorrowPrompt {
    final p = tomorrowPrompt.trim();
    return p.isNotEmpty ? p : ConsumerUiCopy.tomorrowNoticePrompt;
  }

  bool get hasContent =>
      noticedToday.trim().isNotEmpty &&
      comeBackTomorrow.trim().isNotEmpty &&
      watchForNextTime.trim().isNotEmpty;

  bool isSameCalendarDayAs(DateTime other) {
    return generatedAt.year == other.year &&
        generatedAt.month == other.month &&
        generatedAt.day == other.day;
  }

  Map<String, dynamic> toJson() => {
    'noticedToday': noticedToday,
    'comeBackTomorrow': comeBackTomorrow,
    'watchForNextTime': watchForNextTime,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    if (watchForChips.isNotEmpty) 'watchForChips': watchForChips,
    if (tomorrowPrompt.trim().isNotEmpty) 'tomorrowPrompt': tomorrowPrompt,
  };

  static TomorrowReturnLoop? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final noticed = json['noticedToday']?.toString().trim() ?? '';
    final back = json['comeBackTomorrow']?.toString().trim() ?? '';
    final watch = json['watchForNextTime']?.toString().trim() ?? '';
    final atRaw = json['generatedAt']?.toString();
    if (noticed.isEmpty || back.isEmpty || watch.isEmpty || atRaw == null) {
      return null;
    }
    final at = DateTime.tryParse(atRaw);
    if (at == null) return null;
    final chipsRaw = json['watchForChips'];
    final chips = chipsRaw is List
        ? chipsRaw
              .map((e) => e.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList()
        : const <String>[];
    final prompt = json['tomorrowPrompt']?.toString().trim() ?? '';

    return TomorrowReturnLoop(
      noticedToday: noticed,
      comeBackTomorrow: back,
      watchForNextTime: watch,
      generatedAt: at.toLocal(),
      watchForChips: chips,
      tomorrowPrompt: prompt,
    );
  }
}
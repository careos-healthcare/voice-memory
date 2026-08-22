/// Local reminder to return tomorrow and compare reflections.
class TomorrowCommitment {
  const TomorrowCommitment({
    required this.committedAt,
    required this.targetDate,
    required this.promptText,
    required this.watchForChips,
    this.completedAt,
    this.lastOpenedDate,
  });

  final DateTime committedAt;
  final DateTime targetDate;
  final String promptText;
  final List<String> watchForChips;
  final DateTime? completedAt;
  final DateTime? lastOpenedDate;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime tomorrowFrom(DateTime now) =>
      dateOnly(now).add(const Duration(days: 1));

  TomorrowCommitmentDisplayState displayState(DateTime now) {
    final today = dateOnly(now);
    final target = dateOnly(targetDate);
    if (completedAt != null && dateOnly(completedAt!) == today) {
      return TomorrowCommitmentDisplayState.completedToday;
    }
    if (completedAt == null && !today.isBefore(target)) {
      return TomorrowCommitmentDisplayState.awaitingReturn;
    }
    return TomorrowCommitmentDisplayState.hidden;
  }

  bool get hasWatchChips =>
      watchForChips.map((c) => c.trim()).where((c) => c.isNotEmpty).isNotEmpty;

  List<String> get displayWatchChips => watchForChips
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .take(3)
      .toList();

  TomorrowCommitment copyWith({
    DateTime? committedAt,
    DateTime? targetDate,
    String? promptText,
    List<String>? watchForChips,
    DateTime? completedAt,
    DateTime? lastOpenedDate,
    bool clearCompletedAt = false,
    bool clearLastOpenedDate = false,
  }) {
    return TomorrowCommitment(
      committedAt: committedAt ?? this.committedAt,
      targetDate: targetDate ?? this.targetDate,
      promptText: promptText ?? this.promptText,
      watchForChips: watchForChips ?? this.watchForChips,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      lastOpenedDate: clearLastOpenedDate
          ? null
          : (lastOpenedDate ?? this.lastOpenedDate),
    );
  }

  Map<String, dynamic> toJson() => {
    'committedAt': committedAt.toUtc().toIso8601String(),
    'targetDate': dateOnly(targetDate).toIso8601String(),
    'promptText': promptText,
    'watchForChips': watchForChips,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (lastOpenedDate != null)
      'lastOpenedDate': lastOpenedDate!.toUtc().toIso8601String(),
  };

  static TomorrowCommitment? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final committedRaw = json['committedAt']?.toString();
    final targetRaw = json['targetDate']?.toString();
    final prompt = json['promptText']?.toString().trim() ?? '';
    if (committedRaw == null || targetRaw == null || prompt.isEmpty) {
      return null;
    }
    final committedAt = DateTime.tryParse(committedRaw);
    final targetDate = DateTime.tryParse(targetRaw);
    if (committedAt == null || targetDate == null) return null;

    final chipsRaw = json['watchForChips'];
    final chips = chipsRaw is List
        ? chipsRaw
              .map((e) => e.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList()
        : <String>[];

    DateTime? completedAt;
    final completedRaw = json['completedAt']?.toString();
    if (completedRaw != null) {
      completedAt = DateTime.tryParse(completedRaw)?.toLocal();
    }

    DateTime? lastOpenedDate;
    final openedRaw = json['lastOpenedDate']?.toString();
    if (openedRaw != null) {
      lastOpenedDate = DateTime.tryParse(openedRaw)?.toLocal();
    }

    return TomorrowCommitment(
      committedAt: committedAt.toLocal(),
      targetDate: dateOnly(targetDate),
      promptText: prompt,
      watchForChips: chips,
      completedAt: completedAt,
      lastOpenedDate: lastOpenedDate,
    );
  }
}

enum TomorrowCommitmentDisplayState { hidden, awaitingReturn, completedToday }
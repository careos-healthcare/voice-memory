import 'check_in_result_copy.dart';
import 'return_capture_model.dart';
import 'watch_for_model.dart';

/// One-tap answer for tomorrow's locked check-in.
class TomorrowCheckInOption {
  const TomorrowCheckInOption({
    required this.id,
    required this.label,
    required this.followUpPrompt,
    required this.comparisonHint,
  });

  final String id;
  final String label;
  final String followUpPrompt;
  final String comparisonHint;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'followUpPrompt': followUpPrompt,
    'comparisonHint': comparisonHint,
  };

  static TomorrowCheckInOption? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return TomorrowCheckInOption(
      id: id,
      label: map['label'] as String? ?? '',
      followUpPrompt: map['followUpPrompt'] as String? ?? '',
      comparisonHint: map['comparisonHint'] as String? ?? '',
    );
  }
}

/// Default four options for return-day check-in.
const List<TomorrowCheckInOption> kDefaultTomorrowCheckInOptions = [
  TomorrowCheckInOption(
    id: 'showed_up_again',
    label: 'It showed up again',
    followUpPrompt: 'What was the moment?',
    comparisonHint: ReturnCaptureComparisonHints.same,
  ),
  TomorrowCheckInOption(
    id: 'lighter',
    label: 'It felt lighter',
    followUpPrompt: 'What made it lighter?',
    comparisonHint: ReturnCaptureComparisonHints.lighter,
  ),
  TomorrowCheckInOption(
    id: 'heavier',
    label: 'It felt heavier',
    followUpPrompt: 'What made it heavier?',
    comparisonHint: ReturnCaptureComparisonHints.heavier,
  ),
  TomorrowCheckInOption(
    id: 'not_today',
    label: 'Not today',
    followUpPrompt: 'What was different?',
    comparisonHint: ReturnCaptureComparisonHints.changed,
  ),
  TomorrowCheckInOption(
    id: 'none_fit',
    label: 'None of these fit',
    followUpPrompt: 'What actually happened?',
    comparisonHint: ReturnCaptureComparisonHints.changed,
  ),
];

/// Locked tomorrow question the user chose to answer on return day.
class TomorrowCheckIn {
  const TomorrowCheckIn({
    required this.id,
    required this.createdAt,
    required this.targetDate,
    required this.patternTitle,
    required this.prompt,
    required this.question,
    required this.options,
    this.selectedOptionId,
    this.completedAt,
    this.sourceWatchForId,
    this.sourcePatternThreadId,
  });

  final String id;
  final DateTime createdAt;
  final String targetDate;
  final String patternTitle;
  final String prompt;
  final String question;
  final List<TomorrowCheckInOption> options;
  final String? selectedOptionId;
  final DateTime? completedAt;
  final String? sourceWatchForId;
  final String? sourcePatternThreadId;

  bool get isCompleted => completedAt != null;

  TomorrowCheckInOption? get selectedOption {
    final id = selectedOptionId;
    if (id == null) return null;
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  String get resultHeadline =>
      CheckInResultCopy.resultHeadline(selectedOptionId);

  String get whatThisMeans => CheckInResultCopy.whatThisMeans(selectedOptionId);

  String get tomorrowsBetterQuestion =>
      CheckInResultCopy.tomorrowsBetterQuestion(selectedOptionId);

  TomorrowCheckIn copyWith({
    String? selectedOptionId,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TomorrowCheckIn(
      id: id,
      createdAt: createdAt,
      targetDate: targetDate,
      patternTitle: patternTitle,
      prompt: prompt,
      question: question,
      options: options,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sourceWatchForId: sourceWatchForId,
      sourcePatternThreadId: sourcePatternThreadId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'targetDate': targetDate,
    'patternTitle': patternTitle,
    'prompt': prompt,
    'question': question,
    'options': options.map((o) => o.toJson()).toList(),
    if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (sourceWatchForId != null) 'sourceWatchForId': sourceWatchForId,
    if (sourcePatternThreadId != null)
      'sourcePatternThreadId': sourcePatternThreadId,
  };

  static TomorrowCheckIn? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdRaw = map['createdAt'] as String?;
    if (createdRaw == null) return null;
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    final targetDate = map['targetDate'] as String? ?? '';
    final optionsRaw = map['options'];
    final options = <TomorrowCheckInOption>[];
    if (optionsRaw is List) {
      for (final e in optionsRaw) {
        final o = TomorrowCheckInOption.fromJson(
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
        );
        if (o != null) options.add(o);
      }
    }
    if (options.isEmpty) {
      options.addAll(kDefaultTomorrowCheckInOptions);
    }
    DateTime? completedAt;
    final completedRaw = map['completedAt'] as String?;
    if (completedRaw != null) {
      completedAt = DateTime.tryParse(completedRaw);
    }
    return TomorrowCheckIn(
      id: id,
      createdAt: createdAt,
      targetDate: targetDate,
      patternTitle: map['patternTitle'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: options,
      selectedOptionId: map['selectedOptionId'] as String?,
      completedAt: completedAt,
      sourceWatchForId: map['sourceWatchForId'] as String?,
      sourcePatternThreadId: map['sourcePatternThreadId'] as String?,
    );
  }
}

/// ISO date key yyyy-MM-dd for [targetDate].
String tomorrowCheckInDateKey(DateTime day) {
  final d = WatchForItem.dateOnly(day);
  final m = d.month.toString().padLeft(2, '0');
  final dayStr = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$dayStr';
}

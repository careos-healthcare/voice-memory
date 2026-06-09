/// Comparison hints from quick answers on return day.
abstract final class ReturnCaptureComparisonHints {
  ReturnCaptureComparisonHints._();

  static const same = 'same';
  static const lighter = 'lighter';
  static const heavier = 'heavier';
  static const changed = 'changed';
}

enum ReturnCaptureQuality {
  low,
  medium,
  high,
}

extension ReturnCaptureQualityIds on ReturnCaptureQuality {
  String get id => name;
}

/// One-tap answer before recording on return day.
class ReturnQuickAnswer {
  const ReturnQuickAnswer({
    required this.id,
    required this.label,
    required this.followUpPrompt,
    required this.comparisonHint,
  });

  final String id;
  final String label;
  final String followUpPrompt;
  final String comparisonHint;
}

/// Guided capture context for a pending watch-for due today.
class ReturnCaptureModel {
  const ReturnCaptureModel({
    required this.watchForId,
    required this.promptText,
    this.checkInQuestion,
    this.situationHint,
    required this.suggestedStarters,
    required this.quickAnswers,
    required this.quality,
  });

  final String watchForId;
  final String promptText;
  final String? checkInQuestion;
  final String? situationHint;
  final List<String> suggestedStarters;
  final List<ReturnQuickAnswer> quickAnswers;
  final ReturnCaptureQuality quality;
}

/// Default quick answers for return-day capture.
const List<ReturnQuickAnswer> kDefaultReturnQuickAnswers = [
  ReturnQuickAnswer(
    id: 'showed_up_again',
    label: 'It showed up again',
    followUpPrompt: 'What was the moment?',
    comparisonHint: ReturnCaptureComparisonHints.same,
  ),
  ReturnQuickAnswer(
    id: 'felt_lighter',
    label: 'It felt lighter',
    followUpPrompt: 'What made it lighter today?',
    comparisonHint: ReturnCaptureComparisonHints.lighter,
  ),
  ReturnQuickAnswer(
    id: 'felt_heavier',
    label: 'It felt heavier',
    followUpPrompt: 'What made it heavier today?',
    comparisonHint: ReturnCaptureComparisonHints.heavier,
  ),
  ReturnQuickAnswer(
    id: 'not_today',
    label: 'Not today',
    followUpPrompt: 'What was different today?',
    comparisonHint: ReturnCaptureComparisonHints.changed,
  ),
];

/// Persisted quick-answer selection before recording.
class ReturnCaptureSelection {
  const ReturnCaptureSelection({
    required this.watchForId,
    required this.selectedQuickAnswerId,
    required this.comparisonHint,
    required this.createdAt,
  });

  final String watchForId;
  final String selectedQuickAnswerId;
  final String comparisonHint;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'watchForId': watchForId,
        'selectedQuickAnswerId': selectedQuickAnswerId,
        'comparisonHint': comparisonHint,
        'createdAt': createdAt.toIso8601String(),
      };

  static ReturnCaptureSelection? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final watchForId = json['watchForId'] as String?;
    final answerId = json['selectedQuickAnswerId'] as String?;
    final hint = json['comparisonHint'] as String?;
    final createdRaw = json['createdAt'] as String?;
    if (watchForId == null ||
        answerId == null ||
        hint == null ||
        createdRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    return ReturnCaptureSelection(
      watchForId: watchForId,
      selectedQuickAnswerId: answerId,
      comparisonHint: hint,
      createdAt: createdAt,
    );
  }
}

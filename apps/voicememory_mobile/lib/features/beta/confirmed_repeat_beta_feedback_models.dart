/// Local beta feedback choice after the first confirmed repeat.
library;

import 'confirmed_repeat_beta_feedback_copy.dart';

enum ConfirmedRepeatBetaFeedbackChoice {
  yes,
  notReally,
  needMore,
}

extension ConfirmedRepeatBetaFeedbackChoiceAnalytics
    on ConfirmedRepeatBetaFeedbackChoice {
  String get analyticsReason => switch (this) {
        ConfirmedRepeatBetaFeedbackChoice.yes => 'yes',
        ConfirmedRepeatBetaFeedbackChoice.notReally => 'not_really',
        ConfirmedRepeatBetaFeedbackChoice.needMore => 'need_more',
      };
}

class ConfirmedRepeatBetaFeedbackState {
  const ConfirmedRepeatBetaFeedbackState({
    this.choice,
    this.note,
    this.dismissed = false,
    this.updatedAt,
  });

  static const empty = ConfirmedRepeatBetaFeedbackState();

  final ConfirmedRepeatBetaFeedbackChoice? choice;
  final String? note;
  final bool dismissed;
  final DateTime? updatedAt;

  bool get completed => dismissed || choice != null;

  bool get hasNote => note != null && note!.trim().isNotEmpty;

  ConfirmedRepeatBetaFeedbackState copyWith({
    ConfirmedRepeatBetaFeedbackChoice? choice,
    String? note,
    bool? dismissed,
    DateTime? updatedAt,
    bool clearNote = false,
  }) {
    return ConfirmedRepeatBetaFeedbackState(
      choice: choice ?? this.choice,
      note: clearNote ? null : (note ?? this.note),
      dismissed: dismissed ?? this.dismissed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (choice != null) 'choice': choice!.name,
        if (note != null && note!.isNotEmpty) 'note': note,
        'dismissed': dismissed,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory ConfirmedRepeatBetaFeedbackState.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    final choiceRaw = json['choice'] as String?;
    return ConfirmedRepeatBetaFeedbackState(
      choice: choiceRaw == null
          ? null
          : ConfirmedRepeatBetaFeedbackChoice.values.firstWhere(
              (value) => value.name == choiceRaw,
              orElse: () => ConfirmedRepeatBetaFeedbackChoice.yes,
            ),
      note: json['note'] as String?,
      dismissed: json['dismissed'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  String toReviewSummary() {
    if (dismissed && choice == null) return 'Dismissed without answering';
    final choiceLabel = switch (choice) {
      ConfirmedRepeatBetaFeedbackChoice.yes => ConfirmedRepeatBetaFeedbackCopy.yes,
      ConfirmedRepeatBetaFeedbackChoice.notReally =>
        ConfirmedRepeatBetaFeedbackCopy.notReally,
      ConfirmedRepeatBetaFeedbackChoice.needMore =>
        ConfirmedRepeatBetaFeedbackCopy.needMore,
      null => 'No choice',
    };
    if (hasNote) {
      return '$choiceLabel — note saved locally';
    }
    return choiceLabel;
  }
}

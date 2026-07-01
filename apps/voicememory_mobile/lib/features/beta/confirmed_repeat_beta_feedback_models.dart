/// Local beta feedback after confirmed repeat / third-recording proof.
library;

import 'confirmed_repeat_beta_feedback_copy.dart';

enum ConfirmedRepeatBetaFeedbackChoice {
  yes,
  somewhat,
  notReally,
}

enum ConfirmedRepeatBetaFeedbackReason {
  tooGeneric,
  wrongPattern,
  repeatedTooMuch,
  missingContext,
}

extension ConfirmedRepeatBetaFeedbackChoiceAnalytics
    on ConfirmedRepeatBetaFeedbackChoice {
  String get analyticsAnswer => switch (this) {
        ConfirmedRepeatBetaFeedbackChoice.yes => 'yes',
        ConfirmedRepeatBetaFeedbackChoice.somewhat => 'somewhat',
        ConfirmedRepeatBetaFeedbackChoice.notReally => 'not_really',
      };

  bool get showsFollowUp => this != ConfirmedRepeatBetaFeedbackChoice.yes;
}

extension ConfirmedRepeatBetaFeedbackReasonAnalytics
    on ConfirmedRepeatBetaFeedbackReason {
  String get analyticsReason => switch (this) {
        ConfirmedRepeatBetaFeedbackReason.tooGeneric => 'too_generic',
        ConfirmedRepeatBetaFeedbackReason.wrongPattern => 'wrong_pattern',
        ConfirmedRepeatBetaFeedbackReason.repeatedTooMuch => 'repeated_too_much',
        ConfirmedRepeatBetaFeedbackReason.missingContext => 'missing_context',
      };

  String get label => switch (this) {
        ConfirmedRepeatBetaFeedbackReason.tooGeneric =>
          ConfirmedRepeatBetaFeedbackCopy.tooGeneric,
        ConfirmedRepeatBetaFeedbackReason.wrongPattern =>
          ConfirmedRepeatBetaFeedbackCopy.wrongPattern,
        ConfirmedRepeatBetaFeedbackReason.repeatedTooMuch =>
          ConfirmedRepeatBetaFeedbackCopy.repeatedTooMuch,
        ConfirmedRepeatBetaFeedbackReason.missingContext =>
          ConfirmedRepeatBetaFeedbackCopy.missingContext,
      };
}

class ConfirmedRepeatBetaFeedbackState {
  const ConfirmedRepeatBetaFeedbackState({
    this.choice,
    this.reason,
    this.note,
    this.dismissed = false,
    this.updatedAt,
  });

  static const empty = ConfirmedRepeatBetaFeedbackState();

  final ConfirmedRepeatBetaFeedbackChoice? choice;
  final ConfirmedRepeatBetaFeedbackReason? reason;
  final String? note;
  final bool dismissed;
  final DateTime? updatedAt;

  bool get completed => dismissed || choice != null;

  bool get hasFollowUpReason => reason != null;

  ConfirmedRepeatBetaFeedbackState copyWith({
    ConfirmedRepeatBetaFeedbackChoice? choice,
    ConfirmedRepeatBetaFeedbackReason? reason,
    String? note,
    bool? dismissed,
    DateTime? updatedAt,
    bool clearReason = false,
    bool clearNote = false,
  }) {
    return ConfirmedRepeatBetaFeedbackState(
      choice: choice ?? this.choice,
      reason: clearReason ? null : (reason ?? this.reason),
      note: clearNote ? null : (note ?? this.note),
      dismissed: dismissed ?? this.dismissed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (choice != null) 'choice': choice!.name,
        if (reason != null) 'reason': reason!.name,
        if (note != null && note!.isNotEmpty) 'note': note,
        'dismissed': dismissed,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory ConfirmedRepeatBetaFeedbackState.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return ConfirmedRepeatBetaFeedbackState(
      choice: _choiceFromRaw(json['choice'] as String?),
      reason: _reasonFromRaw(json['reason'] as String?),
      note: json['note'] as String?,
      dismissed: json['dismissed'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  static ConfirmedRepeatBetaFeedbackChoice? _choiceFromRaw(String? raw) {
    if (raw == null) return null;
    if (raw == 'needMore') {
      return ConfirmedRepeatBetaFeedbackChoice.somewhat;
    }
    return ConfirmedRepeatBetaFeedbackChoice.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ConfirmedRepeatBetaFeedbackChoice.yes,
    );
  }

  static ConfirmedRepeatBetaFeedbackReason? _reasonFromRaw(String? raw) {
    if (raw == null) return null;
    return ConfirmedRepeatBetaFeedbackReason.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ConfirmedRepeatBetaFeedbackReason.tooGeneric,
    );
  }

  String toReviewSummary() {
    if (dismissed && choice == null) return 'Dismissed without answering';
    final choiceLabel = switch (choice) {
      ConfirmedRepeatBetaFeedbackChoice.yes => ConfirmedRepeatBetaFeedbackCopy.yes,
      ConfirmedRepeatBetaFeedbackChoice.somewhat =>
        ConfirmedRepeatBetaFeedbackCopy.somewhat,
      ConfirmedRepeatBetaFeedbackChoice.notReally =>
        ConfirmedRepeatBetaFeedbackCopy.notReally,
      null => 'No choice',
    };
    if (reason != null) {
      return '$choiceLabel — ${reason!.label}';
    }
    if (note != null && note!.trim().isNotEmpty) {
      return '$choiceLabel — legacy note saved locally';
    }
    return choiceLabel;
  }
}

import 'core_value_feedback_copy.dart';

enum CoreValueFeedbackAnswer { yes, notYet, generic }

enum CoreValueFeedbackSource { recordPostFirstProof, patternsArchive }

extension CoreValueFeedbackAnswerStorage on CoreValueFeedbackAnswer {
  String get storageValue => switch (this) {
    CoreValueFeedbackAnswer.yes => 'yes',
    CoreValueFeedbackAnswer.notYet => 'not_yet',
    CoreValueFeedbackAnswer.generic => 'generic',
  };

  String get analyticsValue => storageValue;

  String get diagnosticsLabel => switch (this) {
    CoreValueFeedbackAnswer.yes => CoreValueFeedbackCopy.answerYes,
    CoreValueFeedbackAnswer.notYet => CoreValueFeedbackCopy.answerNotYet,
    CoreValueFeedbackAnswer.generic => CoreValueFeedbackCopy.answerGeneric,
  };
}

extension CoreValueFeedbackSourceStorage on CoreValueFeedbackSource {
  String get storageValue => switch (this) {
    CoreValueFeedbackSource.recordPostFirstProof => 'record_post_first_proof',
    CoreValueFeedbackSource.patternsArchive => 'patterns_archive',
  };

  String get analyticsValue => storageValue;
}

/// Local-only core value beta feedback — no journal text.
class CoreValueFeedbackRecord {
  const CoreValueFeedbackRecord({
    this.answer,
    this.timestamp,
    this.entryCount,
    this.source,
  });

  static const empty = CoreValueFeedbackRecord();

  final CoreValueFeedbackAnswer? answer;
  final DateTime? timestamp;
  final int? entryCount;
  final CoreValueFeedbackSource? source;

  bool get answered => answer != null;

  String get diagnosticsSummary =>
      answer?.diagnosticsLabel ?? CoreValueFeedbackCopy.diagnosticsNoAnswer;

  CoreValueFeedbackRecord copyWith({
    CoreValueFeedbackAnswer? answer,
    DateTime? timestamp,
    int? entryCount,
    CoreValueFeedbackSource? source,
    bool clearAnswer = false,
  }) {
    return CoreValueFeedbackRecord(
      answer: clearAnswer ? null : (answer ?? this.answer),
      timestamp: timestamp ?? this.timestamp,
      entryCount: entryCount ?? this.entryCount,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    if (answer != null) 'answer': answer!.storageValue,
    if (timestamp != null) 'timestamp': timestamp!.toUtc().toIso8601String(),
    if (entryCount != null) 'entryCount': entryCount,
    if (source != null) 'source': source!.storageValue,
  };

  factory CoreValueFeedbackRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return CoreValueFeedbackRecord(
      answer: _answerFromRaw(json['answer'] as String?),
      timestamp: _timestampFromRaw(json['timestamp'] as String?),
      entryCount: json['entryCount'] is int ? json['entryCount'] as int : null,
      source: _sourceFromRaw(json['source'] as String?),
    );
  }

  static CoreValueFeedbackAnswer? _answerFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return CoreValueFeedbackAnswer.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => CoreValueFeedbackAnswer.yes,
    );
  }

  static CoreValueFeedbackSource? _sourceFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return CoreValueFeedbackSource.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => CoreValueFeedbackSource.recordPostFirstProof,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

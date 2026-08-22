import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_copy.dart';

enum RepeatReturnCheckChoice {
  stronger,
  same,
  softer,
  changed;

  String get analyticsReason => switch (this) {
    RepeatReturnCheckChoice.stronger => 'stronger',
    RepeatReturnCheckChoice.same => 'same',
    RepeatReturnCheckChoice.softer => 'softer',
    RepeatReturnCheckChoice.changed => 'changed',
  };

  String get label => switch (this) {
    RepeatReturnCheckChoice.stronger => RepeatReturnCheckCopy.stronger,
    RepeatReturnCheckChoice.same => RepeatReturnCheckCopy.same,
    RepeatReturnCheckChoice.softer => RepeatReturnCheckCopy.softer,
    RepeatReturnCheckChoice.changed => RepeatReturnCheckCopy.changed,
  };

  /// Ordinal for trend comparison — higher means the repeat felt more intense.
  int get intensity => switch (this) {
    RepeatReturnCheckChoice.softer => 0,
    RepeatReturnCheckChoice.same => 1,
    RepeatReturnCheckChoice.stronger => 2,
    RepeatReturnCheckChoice.changed => 1,
  };

  /// Choices offered on the legacy repeat return check card.
  static const List<RepeatReturnCheckChoice> legacyOfferChoices = [
    RepeatReturnCheckChoice.softer,
    RepeatReturnCheckChoice.stronger,
    RepeatReturnCheckChoice.same,
  ];
}

class RepeatReturnCheckRecord {
  const RepeatReturnCheckRecord({
    required this.entryId,
    required this.entryCountAtCapture, required this.createdAt, this.choice,
    this.dismissed = false,
  });

  factory RepeatReturnCheckRecord.fromJson(Map<String, dynamic> json) {
    final choiceRaw = json['choice'] as String?;
    return RepeatReturnCheckRecord(
      entryId: json['entryId'] as String? ?? '',
      choice: choiceRaw == null
          ? null
          : RepeatReturnCheckChoice.values.firstWhere(
              (value) => value.name == choiceRaw,
              orElse: () => RepeatReturnCheckChoice.same,
            ),
      dismissed: json['dismissed'] == true,
      entryCountAtCapture: (json['entryCountAtCapture'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String entryId;
  final RepeatReturnCheckChoice? choice;
  final bool dismissed;
  final int entryCountAtCapture;
  final DateTime createdAt;

  bool get completed => dismissed || choice != null;

  RepeatReturnCheckRecord copyWith({
    RepeatReturnCheckChoice? choice,
    bool? dismissed,
    DateTime? createdAt,
  }) {
    return RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice ?? this.choice,
      dismissed: dismissed ?? this.dismissed,
      entryCountAtCapture: entryCountAtCapture,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    if (choice != null) 'choice': choice!.name,
    'dismissed': dismissed,
    'entryCountAtCapture': entryCountAtCapture,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
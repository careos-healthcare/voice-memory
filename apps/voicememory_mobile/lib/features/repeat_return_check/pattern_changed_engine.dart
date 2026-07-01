import 'repeat_return_check_change_proof.dart';
import 'repeat_return_check_copy.dart';
import 'repeat_return_check_models.dart';
import 'repeat_return_check_trend.dart';
import 'pattern_changed_copy.dart';

enum PatternChangedType {
  softer,
  changed,
  stronger;

  String get analyticsValue => name;

  bool get isCelebration => switch (this) {
        PatternChangedType.softer || PatternChangedType.changed => true,
        PatternChangedType.stronger => false,
      };
}

/// Built pattern-changed card from repeat return check evidence.
class PatternChangedResult {
  const PatternChangedResult({
    required this.type,
    required this.title,
    required this.body,
    required this.entryId,
    required this.isCelebration,
  });

  final PatternChangedType type;
  final String title;
  final String body;
  final String entryId;
  final bool isCelebration;
}

abstract final class PatternChangedEngine {
  PatternChangedEngine._();

  static PatternChangedResult? build({
    required RepeatReturnCheckChangeProof? changeProof,
    required List<RepeatReturnCheckRecord> records,
  }) {
    if (changeProof == null) return null;
    if (!RepeatReturnCheckTrendEngine.hasAnsweredCheck(records)) return null;

    final entryId = _latestAnsweredEntryId(records);
    if (entryId == null || entryId.isEmpty) return null;

    final type = _resolveType(records, changeProof.latestChoice);
    if (type == null) return null;

    final (title, body) = _copyFor(type);
    return PatternChangedResult(
      type: type,
      title: title,
      body: body,
      entryId: entryId,
      isCelebration: type.isCelebration,
    );
  }

  static PatternChangedType? _resolveType(
    List<RepeatReturnCheckRecord> records,
    RepeatReturnCheckChoice latestChoice,
  ) {
    final choices = records
        .where((record) => record.choice != null)
        .map((record) => record.choice!)
        .toList();
    if (choices.isEmpty) return null;

    final trend = RepeatReturnCheckTrendEngine.latestTrendCopy(records);

    if (choices.length >= 2) {
      final latest = choices.first;
      final prior = choices[1];
      if (latest == RepeatReturnCheckChoice.same && prior != latest) {
        if (trend == RepeatReturnCheckCopy.trendGettingLouder) {
          return PatternChangedType.changed;
        }
      }
    }

    if (trend == RepeatReturnCheckCopy.trendSofterThanBefore) {
      return PatternChangedType.softer;
    }
    if (trend == RepeatReturnCheckCopy.trendGettingLouder) {
      return PatternChangedType.stronger;
    }

    return switch (latestChoice) {
      RepeatReturnCheckChoice.softer => PatternChangedType.softer,
      RepeatReturnCheckChoice.stronger => PatternChangedType.stronger,
      RepeatReturnCheckChoice.same => null,
    };
  }

  static String? _latestAnsweredEntryId(List<RepeatReturnCheckRecord> records) {
    for (final record in records) {
      if (record.choice != null) return record.entryId;
    }
    return null;
  }

  static (String title, String body) _copyFor(PatternChangedType type) =>
      switch (type) {
        PatternChangedType.softer => (
            PatternChangedCopy.softerTitle,
            PatternChangedCopy.softerBody,
          ),
        PatternChangedType.changed => (
            PatternChangedCopy.changedTitle,
            PatternChangedCopy.changedBody,
          ),
        PatternChangedType.stronger => (
            PatternChangedCopy.strongerTitle,
            PatternChangedCopy.strongerBody,
          ),
      };
}

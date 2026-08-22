import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';

/// Summarises user-reported repeat intensity for proof surfaces.
abstract final class RepeatReturnCheckTrendEngine {
  RepeatReturnCheckTrendEngine._();

  static bool hasAnsweredCheck(List<RepeatReturnCheckRecord> records) =>
      records.any((record) => record.choice != null);

  static RepeatReturnCheckChoice? latestChoice(
    List<RepeatReturnCheckRecord> records,
  ) {
    for (final record in records) {
      if (record.choice != null) return record.choice;
    }
    return null;
  }

  static String bodyForChoice(RepeatReturnCheckChoice choice) =>
      switch (choice) {
        RepeatReturnCheckChoice.stronger =>
          RepeatReturnCheckCopy.trendGettingLouder,
        RepeatReturnCheckChoice.softer =>
          RepeatReturnCheckCopy.trendSofterThanBefore,
        RepeatReturnCheckChoice.same => RepeatReturnCheckCopy.trendSteady,
        RepeatReturnCheckChoice.changed => RepeatReturnCheckCopy.trendSteady,
      };

  /// Compares the two most recent answers when available; otherwise maps the
  /// latest single answer to proof copy.
  static String? changeProofBody(List<RepeatReturnCheckRecord> records) {
    if (!hasAnsweredCheck(records)) return null;

    final compared = latestTrendCopy(records);
    if (compared != null) return compared;

    final latest = latestChoice(records);
    if (latest == null) return null;
    return bodyForChoice(latest);
  }

  static String? latestTrendCopy(List<RepeatReturnCheckRecord> records) {
    final choices = records
        .where(
          (record) =>
              record.choice != null &&
              record.choice != RepeatReturnCheckChoice.changed,
        )
        .map((record) => record.choice!)
        .toList();
    if (choices.length < 2) return null;

    final latest = choices.first.intensity;
    final prior = choices[1].intensity;
    if (latest > prior) return RepeatReturnCheckCopy.trendGettingLouder;
    if (latest < prior) return RepeatReturnCheckCopy.trendSofterThanBefore;
    return RepeatReturnCheckCopy.trendSteady;
  }
}
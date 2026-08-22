import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';

/// A plain count of the feedback ArchiveMe has received so far, plus the one
/// issue (if any) worth gently adjusting future output for.
class ArchiveFeedbackSummary {
  const ArchiveFeedbackSummary({
    required this.total,
    required this.usefulCount,
    required this.tooGenericCount,
    required this.notMeCount,
    required this.alreadyKnewCount,
    required this.moreSpecificCount,
    this.dominantIssue,
  });

  final int total;
  final int usefulCount;
  final int tooGenericCount;
  final int notMeCount;
  final int alreadyKnewCount;
  final int moreSpecificCount;

  /// The most common correction, only when it has shown up at least twice.
  final ArchiveFeedbackType? dominantIssue;

  static const empty = ArchiveFeedbackSummary(
    total: 0,
    usefulCount: 0,
    tooGenericCount: 0,
    notMeCount: 0,
    alreadyKnewCount: 0,
    moreSpecificCount: 0,
  );

  int countFor(ArchiveFeedbackType type) {
    switch (type) {
      case ArchiveFeedbackType.useful:
        return usefulCount;
      case ArchiveFeedbackType.tooGeneric:
        return tooGenericCount;
      case ArchiveFeedbackType.notMe:
        return notMeCount;
      case ArchiveFeedbackType.alreadyKnew:
        return alreadyKnewCount;
      case ArchiveFeedbackType.moreSpecific:
        return moreSpecificCount;
    }
  }
}

/// Builds a [ArchiveFeedbackSummary] from raw feedback rows.
///
/// `dominantIssue` is the negative type with the highest count, but only when
/// that count is at least two — a single tap is never enough to change behavior.
ArchiveFeedbackSummary buildArchiveFeedbackSummary(
  List<ArchiveFeedback> feedback,
) {
  if (feedback.isEmpty) return ArchiveFeedbackSummary.empty;

  var useful = 0;
  var tooGeneric = 0;
  var notMe = 0;
  var alreadyKnew = 0;
  var moreSpecific = 0;

  for (final f in feedback) {
    switch (f.type) {
      case ArchiveFeedbackType.useful:
        useful++;
      case ArchiveFeedbackType.tooGeneric:
        tooGeneric++;
      case ArchiveFeedbackType.notMe:
        notMe++;
      case ArchiveFeedbackType.alreadyKnew:
        alreadyKnew++;
      case ArchiveFeedbackType.moreSpecific:
        moreSpecific++;
    }
  }

  // Stable priority for ties, so the dominant issue is deterministic.
  const negatives = [
    ArchiveFeedbackType.tooGeneric,
    ArchiveFeedbackType.notMe,
    ArchiveFeedbackType.alreadyKnew,
    ArchiveFeedbackType.moreSpecific,
  ];
  final counts = {
    ArchiveFeedbackType.tooGeneric: tooGeneric,
    ArchiveFeedbackType.notMe: notMe,
    ArchiveFeedbackType.alreadyKnew: alreadyKnew,
    ArchiveFeedbackType.moreSpecific: moreSpecific,
  };
  ArchiveFeedbackType? dominant;
  var best = 0;
  for (final type in negatives) {
    final count = counts[type]!;
    if (count > best) {
      best = count;
      dominant = type;
    }
  }
  if (best < 2) {
    dominant = null;
  } else {
    var tiedAtTop = 0;
    for (final type in negatives) {
      if (counts[type] == best) tiedAtTop++;
    }
    if (tiedAtTop > 1) dominant = null;
  }

  return ArchiveFeedbackSummary(
    total: feedback.length,
    usefulCount: useful,
    tooGenericCount: tooGeneric,
    notMeCount: notMe,
    alreadyKnewCount: alreadyKnew,
    moreSpecificCount: moreSpecific,
    dominantIssue: dominant,
  );
}
import '../../models/journal_entry.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'archive_state_action_copy.dart';
import 'archive_state_action_model.dart';
import 'next_best_action_engine.dart';
import 'next_best_action_model.dart';

/// Central archive state → action → destination map.
abstract final class ArchiveStateActionEngine {
  ArchiveStateActionEngine._();

  static ArchiveStateActionResult build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool helpfulActionCapturedMilestone = false,
    bool privateReportForming = false,
  }) {
    final nextBest = NextBestActionEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      privateReportForming: privateReportForming,
    );
    return _fromNextBest(nextBest);
  }

  static ArchiveStateActionResult _fromNextBest(NextBestActionResult nextBest) {
    final kind = _kindFromNextBest(nextBest.kind);
    return ArchiveStateActionResult(
      kind: kind,
      actionLabel: _actionLabel(kind),
      baseDestination: _baseDestination(kind),
    );
  }

  static ArchiveStateActionKind _kindFromNextBest(NextBestActionKind kind) {
    return switch (kind) {
      NextBestActionKind.noEntries => ArchiveStateActionKind.noEntries,
      NextBestActionKind.oneEntry => ArchiveStateActionKind.oneEntry,
      NextBestActionKind.twoNoClearMatch =>
        ArchiveStateActionKind.twoUnrelated,
      NextBestActionKind.twoRelated => ArchiveStateActionKind.twoRelated,
      NextBestActionKind.firstProof => ArchiveStateActionKind.firstProof,
      NextBestActionKind.returnCheckUnanswered =>
        ArchiveStateActionKind.returnCheckUnanswered,
      NextBestActionKind.returnCheckAnswered =>
        ArchiveStateActionKind.returnCheckAnswered,
      NextBestActionKind.patternChanged =>
        ArchiveStateActionKind.patternChanged,
      NextBestActionKind.helpfulActionAppeared =>
        ArchiveStateActionKind.helpfulActionAppeared,
      NextBestActionKind.privateReportForming =>
        ArchiveStateActionKind.privateReportForming,
    };
  }

  static String _actionLabel(ArchiveStateActionKind kind) {
    return switch (kind) {
      ArchiveStateActionKind.noEntries =>
        ArchiveStateActionCopy.noEntries,
      ArchiveStateActionKind.oneEntry => ArchiveStateActionCopy.oneEntry,
      ArchiveStateActionKind.twoUnrelated =>
        ArchiveStateActionCopy.twoUnrelated,
      ArchiveStateActionKind.twoRelated => ArchiveStateActionCopy.twoRelated,
      ArchiveStateActionKind.firstProof => ArchiveStateActionCopy.firstProof,
      ArchiveStateActionKind.returnCheckUnanswered =>
        ArchiveStateActionCopy.returnCheckUnanswered,
      ArchiveStateActionKind.returnCheckAnswered =>
        ArchiveStateActionCopy.returnCheckAnswered,
      ArchiveStateActionKind.patternChanged =>
        ArchiveStateActionCopy.patternChanged,
      ArchiveStateActionKind.helpfulActionAppeared =>
        ArchiveStateActionCopy.helpfulActionAppeared,
      ArchiveStateActionKind.privateReportForming =>
        ArchiveStateActionCopy.privateReportForming,
    };
  }

  static ArchiveStateActionDestination _baseDestination(
    ArchiveStateActionKind kind,
  ) {
    return switch (kind) {
      ArchiveStateActionKind.noEntries ||
      ArchiveStateActionKind.oneEntry ||
      ArchiveStateActionKind.twoUnrelated ||
      ArchiveStateActionKind.twoRelated ||
      ArchiveStateActionKind.firstProof ||
      ArchiveStateActionKind.patternChanged =>
        ArchiveStateActionDestination.recordCapture,
      ArchiveStateActionKind.returnCheckUnanswered =>
        ArchiveStateActionDestination.patterns,
      ArchiveStateActionKind.returnCheckAnswered =>
        ArchiveStateActionDestination.patterns,
      ArchiveStateActionKind.helpfulActionAppeared =>
        ArchiveStateActionDestination.patternsOrTimeline,
      ArchiveStateActionKind.privateReportForming =>
        ArchiveStateActionDestination.recordCapture,
    };
  }
}

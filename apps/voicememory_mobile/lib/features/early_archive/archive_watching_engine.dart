import '../../models/journal_entry.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'archive_watching_copy.dart';
import 'confirmed_repeat_thought_map_engine.dart';
import 'confirmed_repeat_thought_map_models.dart';
import 'positive_pattern_engine.dart';
import 'positive_pattern_models.dart';

/// What the archive is currently watching — grounded gap detection only.
enum ArchiveWatchingKind {
  missingTrigger,
  missingChange,
  missingPositive,
  allKnown,
}

class ArchiveWatchingResult {
  const ArchiveWatchingResult({
    required this.line,
    required this.kind,
  });

  final String line;
  final ArchiveWatchingKind kind;
}

abstract final class ArchiveWatchingEngine {
  ArchiveWatchingEngine._();

  static ArchiveWatchingResult? build({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;

    final thoughtMap = ConfirmedRepeatThoughtMapEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
    );
    final positivePattern = PositivePatternEngine.build(entries: entries);

    if (_missingTrigger(
      thoughtMap,
      triggerCapturedMilestone: triggerCapturedMilestone,
    )) {
      return ArchiveWatchingResult(
        line: ArchiveWatchingCopy.gapLine(
          ArchiveWatchingCopy.missingTriggerFocus,
        ),
        kind: ArchiveWatchingKind.missingTrigger,
      );
    }

    if (changeProof == null) {
      return ArchiveWatchingResult(
        line: ArchiveWatchingCopy.gapLine(
          ArchiveWatchingCopy.missingChangeFocus,
        ),
        kind: ArchiveWatchingKind.missingChange,
      );
    }

    if (positivePattern == null || !positivePattern.hasEvidence) {
      return ArchiveWatchingResult(
        line: ArchiveWatchingCopy.gapLine(
          ArchiveWatchingCopy.missingPositiveFocus,
        ),
        kind: ArchiveWatchingKind.missingPositive,
      );
    }

    return const ArchiveWatchingResult(
      line: ArchiveWatchingCopy.allKnownLine,
      kind: ArchiveWatchingKind.allKnown,
    );
  }

  static bool _missingTrigger(
    ThoughtMapResult? thoughtMap, {
    required bool triggerCapturedMilestone,
  }) {
    if (triggerCapturedMilestone) return false;
    if (thoughtMap == null) return false;
    final trigger = thoughtMap.sections
        .where((section) => section.id == ThoughtMapSectionId.trigger)
        .firstOrNull;
    return trigger != null && !trigger.isKnown;
  }
}

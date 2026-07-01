import '../archive_evidence/archive_belief_thread_copy.dart';
import '../early_archive/early_evidence_timeline_copy.dart';
import '../early_archive/early_first_signal_copy.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import 'archive_proof_surface_layout.dart';
import 'archive_summary_copy.dart';
import 'confirmed_repeat_thought_map_copy.dart';
import 'confirmed_repeat_why_matters_copy.dart';
import 'positive_pattern_copy.dart';
import 'positive_reinforcement_copy.dart';
import 'early_evidence_timeline_engine.dart';

/// Resolves de-duplicated visible copy for proof stacks (tests + policy).
abstract final class ArchiveProofSurfaceCopy {
  ArchiveProofSurfaceCopy._();

  static List<String> recordReadyStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
        patternChanged: patternChanged,
      );

  static List<String> patternsStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
        patternChanged: patternChanged,
      );

  static List<String> _stack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
    PatternChangedResult? patternChanged,
  }) {
    final blocks = <String>[];

    if (layout.confirmedRepeatCardVisible && confirmedRepeat != null) {
      blocks.add(confirmedRepeat.title);
      blocks.addAll(confirmedRepeat.lines);
      if (confirmedRepeat.evidenceHeading != null) {
        blocks.add(confirmedRepeat.evidenceHeading!);
      }
      blocks.addAll(confirmedRepeat.evidencePhrases);
      if (confirmedRepeat.evidenceSupportLine != null) {
        blocks.add(confirmedRepeat.evidenceSupportLine!);
      }
    }

    if (layout.timelineVisible && timeline != null) {
      blocks.add(
        layout.timelineNearby
            ? EarlyEvidenceTimelineCopy.nearbyTitle
            : timeline.title,
      );
      blocks.add(
        layout.timelineNearby
            ? EarlyEvidenceTimelineCopy.nearbySubtitle
            : timeline.subtitle,
      );
      if (!layout.suppressTimelineEvidencePhrases) {
        blocks.add(EarlyFirstSignalCopy.evidenceHeading);
        blocks.addAll(timeline.evidencePhrases);
      }
      for (final item in timeline.items) {
        blocks.add(item.title);
        if (!(layout.timelineNearby &&
            item.kind == EarlyEvidenceTimelineItemKind.repeatConfirmed)) {
          blocks.add(item.body);
        }
      }
    }

    if (layout.effectivePatternChangedVisible && patternChanged != null) {
      blocks.add(patternChanged.title);
      blocks.add(patternChanged.body);
    } else if (layout.changeProofVisible && changeProof != null) {
      if (!layout.archiveSummaryVisible) {
        blocks.add(changeProof.title);
        blocks.add(changeProof.body);
        if (changeProof.supportLine != null) {
          blocks.add(changeProof.supportLine!);
        }
      }
    }

    if (layout.proBridgeVisible) {
      blocks.add(ArchiveBeliefThreadCopy.fullArchiveHistoryTitle);
      blocks.add(ArchiveBeliefThreadCopy.fullArchiveHistoryBody);
    }

    if (layout.whyMattersVisible && !layout.archiveSummaryVisible) {
      blocks.add(ConfirmedRepeatWhyMattersCopy.title);
      blocks.add(ConfirmedRepeatWhyMattersCopy.body);
    }

    if (layout.thoughtMapVisible && !layout.archiveSummaryVisible) {
      blocks.add(ConfirmedRepeatThoughtMapCopy.title);
      for (final label in [
        ConfirmedRepeatThoughtMapCopy.triggerLabel,
        ConfirmedRepeatThoughtMapCopy.thoughtLabel,
        ConfirmedRepeatThoughtMapCopy.actionLabel,
        ConfirmedRepeatThoughtMapCopy.resultLabel,
      ]) {
        blocks.add(label);
      }
    }

    if (layout.effectivePositiveReinforcementVisible) {
      blocks.add(PositiveReinforcementCopy.title);
      blocks.add(PositiveReinforcementCopy.body);
    } else if (layout.effectivePositivePatternVisible) {
      blocks.add(PositivePatternCopy.title);
      blocks.add(PositivePatternCopy.body);
    }

    if (layout.archiveSummaryVisible) {
      blocks.add(ArchiveSummaryCopy.title);
      blocks.add(ArchiveSummaryCopy.keepsRepeatingLabel);
      if (layout.thoughtMapVisible || layout.archiveSummaryVisible) {
        blocks.add(ArchiveSummaryCopy.loopFormingLabel);
      }
      blocks.add(ArchiveSummaryCopy.changingLabel);
      blocks.add(ArchiveSummaryCopy.whatHelpsLabel);
      blocks.add(ArchiveSummaryCopy.recordNextLabel);
    }

    return blocks.where((block) => block.trim().isNotEmpty).toList();
  }
}

import '../archive_evidence/archive_belief_thread_copy.dart';
import '../early_archive/early_evidence_timeline_copy.dart';
import '../early_archive/early_first_signal_copy.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_copy.dart';
import 'archive_proof_surface_layout.dart';
import 'confirmed_repeat_why_matters_copy.dart';
import 'early_evidence_timeline_engine.dart';

/// Resolves de-duplicated visible copy for proof stacks (tests + policy).
abstract final class ArchiveProofSurfaceCopy {
  ArchiveProofSurfaceCopy._();

  static List<String> recordReadyStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
      );

  static List<String> patternsStack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
  }) =>
      _stack(
        layout: layout,
        confirmedRepeat: confirmedRepeat,
        timeline: timeline,
        changeProof: changeProof,
      );

  static List<String> _stack({
    required ArchiveProofSurfaceLayout layout,
    EarlyFirstSignalModel? confirmedRepeat,
    EarlyEvidenceTimeline? timeline,
    RepeatReturnCheckChangeProof? changeProof,
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

    if (layout.changeProofVisible && changeProof != null) {
      blocks.add(changeProof.title);
      blocks.add(changeProof.body);
      if (changeProof.supportLine != null) {
        blocks.add(changeProof.supportLine!);
      }
    }

    if (layout.proBridgeVisible) {
      blocks.add(
        layout.proBridgeCompact
            ? ArchiveBeliefThreadCopy.proNearbyTitle
            : ArchiveBeliefThreadCopy.proKeepsThread,
      );
      blocks.add(
        layout.proBridgeCompact
            ? ArchiveBeliefThreadCopy.proNearbyBridgeBody
            : ArchiveBeliefThreadCopy.proBridgeBody,
      );
    }

    if (layout.whyMattersVisible) {
      blocks.add(ConfirmedRepeatWhyMattersCopy.title);
      blocks.add(ConfirmedRepeatWhyMattersCopy.body);
    }

    return blocks.where((block) => block.trim().isNotEmpty).toList();
  }
}

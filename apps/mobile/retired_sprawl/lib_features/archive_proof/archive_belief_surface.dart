import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_intelligence_tier.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_demo_preview_model.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_demo_preview_resolver.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_display_copy_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Display model for the archive belief proof surface.
class ArchiveBeliefSurface {
  const ArchiveBeliefSurface({
    required this.shouldShow,
    required this.isPreview,
    required this.headline,
    required this.beliefSummary,
    required this.evidenceSummary,
    this.evidencePhrases = const [],
    this.whatChangedSummary,
    this.watchingNextLine,
    this.confidenceLabel,
    this.recordNextCta,
    this.isPrimaryAfterFirstProof = false,
    this.thread,
    this.preview,
  });

  final bool shouldShow;
  final bool isPreview;
  final String headline;
  final String beliefSummary;
  final String evidenceSummary;
  final List<String> evidencePhrases;
  final String? whatChangedSummary;
  final String? watchingNextLine;
  final String? confidenceLabel;
  final String? recordNextCta;
  final bool isPrimaryAfterFirstProof;
  final ArchiveBeliefThread? thread;
  final ArchiveDemoPreview? preview;

  static const none = ArchiveBeliefSurface(
    shouldShow: false,
    isPreview: false,
    headline: '',
    beliefSummary: '',
    evidenceSummary: '',
  );

  /// Zero-entry static preview — no fabricated user-specific patterns.
  static const emptyStaticPreview = ArchiveBeliefSurface(
    shouldShow: true,
    isPreview: true,
    headline: ArchiveBeliefSurfaceCopy.headlineStarting,
    beliefSummary: VisibleArchiveProofCopy.emptyProofBelief,
    evidenceSummary: VisibleArchiveProofCopy.emptyProofEvidence,
    whatChangedSummary: VisibleArchiveProofCopy.emptyProofChanged,
    recordNextCta: VisibleArchiveProofCopy.patternsEmptyPreviewCta,
  );
}

/// Builds [ArchiveBeliefSurface] from existing archive engines only.
class ArchiveBeliefSurfaceSource {
  const ArchiveBeliefSurfaceSource({
    ArchiveBeliefThreadEngine? beliefEngine,
    ArchiveDemoPreviewResolver? previewResolver,
  }) : _beliefEngine = beliefEngine ?? const ArchiveBeliefThreadEngine(),
       _previewResolver = previewResolver ?? const ArchiveDemoPreviewResolver();

  final ArchiveBeliefThreadEngine _beliefEngine;
  final ArchiveDemoPreviewResolver _previewResolver;

  ArchiveBeliefSurface resolve(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (entries.isEmpty) {
      return ArchiveBeliefSurface.emptyStaticPreview;
    }

    final currentBelief = ArchiveCurrentBeliefEngine.build(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      changeProof: changeProof,
      returnChecks: returnChecks,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    if (currentBelief != null) {
      return currentBelief;
    }

    final thread = _beliefEngine.build(entries, tier: tier);
    if (thread.hasEnoughData &&
        !ArchiveBeliefCorrectionStore.isDismissed(thread.suggestionId)) {
      return _fromThread(thread, isWeak: false);
    }

    final preview = _previewResolver.resolve(entries);
    if (preview.shouldShow) {
      return _fromPreview(preview);
    }

    if (thread.hasEnoughData) return ArchiveBeliefSurface.none;
    return ArchiveBeliefSurface.none;
  }

  ArchiveBeliefSurface _fromThread(
    ArchiveBeliefThread thread, {
    required bool isWeak,
  }) {
    final belief = ArchiveDisplayCopyGuard.displayOrEmpty(thread.currentBelief);
    final evidence = ArchiveDisplayCopyGuard.displayOrEmpty(
      thread.evidenceLine,
    );
    if (belief.isEmpty || evidence.isEmpty) return ArchiveBeliefSurface.none;

    final whatChanged = ArchiveDisplayCopyGuard.sanitize(thread.whatChanged);
    final confidence = thread.confidenceBand?.label;
    final recordNext =
        ArchiveDisplayCopyGuard.sanitize(thread.whatToTest) ??
        ArchiveBeliefSurfaceCopy.recordNextCta;

    return ArchiveBeliefSurface(
      shouldShow: true,
      isPreview: false,
      headline: isWeak
          ? ArchiveBeliefSurfaceCopy.headlineStarting
          : ArchiveBeliefSurfaceCopy.headline,
      beliefSummary: belief,
      evidenceSummary: evidence,
      whatChangedSummary: whatChanged,
      confidenceLabel: confidence,
      recordNextCta: recordNext,
      thread: thread,
    );
  }

  ArchiveBeliefSurface _fromPreview(ArchiveDemoPreview preview) {
    return ArchiveBeliefSurface(
      shouldShow: true,
      isPreview: true,
      headline: ArchiveBeliefSurfaceCopy.headlineStarting,
      beliefSummary: ArchiveDisplayCopyGuard.displayOrEmpty(
        preview.patternFirstSeen,
      ),
      evidenceSummary: ArchiveDisplayCopyGuard.displayOrEmpty(
        preview.repeatWouldBe,
      ),
      whatChangedSummary: ArchiveDisplayCopyGuard.sanitize(
        preview.softeningWouldBe,
      ),
      recordNextCta: ArchiveDisplayCopyGuard.sanitize(preview.recordNext),
      preview: preview,
    );
  }
}
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_belief_correction_store.dart';
import '../archive_evidence/archive_belief_thread_engine.dart';
import '../archive_evidence/archive_belief_thread_model.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_intelligence_tier.dart';
import 'archive_belief_surface_copy.dart';
import 'archive_demo_preview_model.dart';
import 'archive_demo_preview_resolver.dart';
import 'archive_display_copy_guard.dart';

/// Display model for the archive belief proof surface.
class ArchiveBeliefSurface {
  const ArchiveBeliefSurface({
    required this.shouldShow,
    required this.isPreview,
    required this.headline,
    required this.beliefSummary,
    required this.evidenceSummary,
    this.whatChangedSummary,
    this.confidenceLabel,
    this.recordNextCta,
    this.thread,
    this.preview,
  });

  final bool shouldShow;
  final bool isPreview;
  final String headline;
  final String beliefSummary;
  final String evidenceSummary;
  final String? whatChangedSummary;
  final String? confidenceLabel;
  final String? recordNextCta;
  final ArchiveBeliefThread? thread;
  final ArchiveDemoPreview? preview;

  static const none = ArchiveBeliefSurface(
    shouldShow: false,
    isPreview: false,
    headline: '',
    beliefSummary: '',
    evidenceSummary: '',
  );
}

/// Builds [ArchiveBeliefSurface] from existing archive engines only.
class ArchiveBeliefSurfaceSource {
  const ArchiveBeliefSurfaceSource({
    ArchiveBeliefThreadEngine? beliefEngine,
    ArchiveDemoPreviewResolver? previewResolver,
  })  : _beliefEngine = beliefEngine ?? const ArchiveBeliefThreadEngine(),
        _previewResolver = previewResolver ?? const ArchiveDemoPreviewResolver();

  final ArchiveBeliefThreadEngine _beliefEngine;
  final ArchiveDemoPreviewResolver _previewResolver;

  ArchiveBeliefSurface resolve(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
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
    final evidence =
        ArchiveDisplayCopyGuard.displayOrEmpty(thread.evidenceLine);
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

import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../early_archive/archive_watching_copy.dart';
import '../early_archive/archive_watching_engine.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'archive_belief_surface.dart';
import 'archive_belief_surface_copy.dart';
import 'archive_display_copy_guard.dart';

/// Builds the main post-first-proof belief surface from grounded engines only.
abstract final class ArchiveCurrentBeliefEngine {
  ArchiveCurrentBeliefEngine._();

  static const maxEvidencePhrases = 3;

  static ArchiveBeliefSurface? build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }

    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return null;

    final signal =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: entries);
    if (signal == null) return null;

    final eligible = ArchiveEvidenceGuard.strongEntries(entries);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      signal.evidencePhrases,
      eligible,
    );
    final phrases = grounded.take(maxEvidencePhrases).toList();
    if (phrases.isEmpty) return null;

    final belief = _beliefSentence(phrases.first);
    if (!ArchiveDisplayCopyGuard.passes(belief)) return null;

    final whatChanged = _whatChangedRecently(changeProof);
    final watching = ArchiveWatchingEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );

    return ArchiveBeliefSurface(
      shouldShow: true,
      isPreview: false,
      isPrimaryAfterFirstProof: true,
      headline: ArchiveBeliefSurfaceCopy.headline,
      beliefSummary: belief,
      evidenceSummary: '',
      evidencePhrases: phrases,
      whatChangedSummary: whatChanged,
      watchingNextLine: _watchingLine(watching?.line),
      recordNextCta: ArchiveBeliefSurfaceCopy.recordNextCta,
    );
  }

  static String _beliefSentence(String primaryPhrase) {
    final phrase = primaryPhrase.trim();
    if (phrase.isEmpty) {
      return ArchiveBeliefSurfaceCopy.beliefFallback;
    }
    return ArchiveBeliefSurfaceCopy.beliefWithPhrase(phrase);
  }

  static String? _whatChangedRecently(
    RepeatReturnCheckChangeProof? changeProof,
  ) {
    final fromProof = ArchiveDisplayCopyGuard.sanitize(changeProof?.body);
    if (fromProof != null) return fromProof;
    return ArchiveBeliefSurfaceCopy.whatChangedFallback;
  }

  static String? _watchingLine(String? watchingLine) {
    final sanitized = ArchiveDisplayCopyGuard.sanitize(watchingLine);
    if (sanitized == null) return ArchiveBeliefSurfaceCopy.watchingFallback;

    if (sanitized == ArchiveWatchingCopy.allKnownLine) {
      return ArchiveBeliefSurfaceCopy.watchingAllKnown;
    }

    for (final focus in [
      ArchiveWatchingCopy.missingTriggerFocus,
      ArchiveWatchingCopy.missingChangeFocus,
      ArchiveWatchingCopy.missingPositiveFocus,
    ]) {
      if (sanitized.contains(focus)) {
        return ArchiveBeliefSurfaceCopy.stillWatching(focus);
      }
    }

    return ArchiveBeliefSurfaceCopy.stillWatching(
      sanitized.replaceFirst(ArchiveWatchingCopy.prefix, '').trim(),
    );
  }
}

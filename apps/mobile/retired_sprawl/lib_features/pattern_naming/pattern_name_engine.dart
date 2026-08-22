import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_model.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Display-only pattern naming — does not change evidence or proof engines.
abstract final class PatternNameEngine {
  PatternNameEngine._();

  static String patternKey(String groundedPhrase) {
    return groundedPhrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static PatternNamePrompt? buildPrompt({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
  }) {
    if (!_allowsPrompt(entries)) return null;

    final signal =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: entries);
    if (signal == null || !signal.showsConfirmedRepeat) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      signal.evidencePhrases,
      eligible,
    );
    if (grounded.isEmpty) return null;

    final primaryPhrase = grounded.first.trim();
    if (primaryPhrase.isEmpty) return null;

    final key = patternKey(primaryPhrase);
    if (PatternNameStore.isResolved(key)) return null;

    return PatternNamePrompt(
      patternKey: key,
      groundedPhrase: primaryPhrase,
      displayLabel: PatternNameStore.displayLabel(
        patternKey: key,
        groundedPhrase: primaryPhrase,
      ),
    );
  }

  static String displayLabelForGroundedPhrase(String groundedPhrase) {
    final trimmed = groundedPhrase.trim();
    if (trimmed.isEmpty) return trimmed;
    final key = patternKey(trimmed);
    return PatternNameStore.displayLabel(
      patternKey: key,
      groundedPhrase: trimmed,
    );
  }

  static ArchiveBeliefSurface applyDisplayLabels(ArchiveBeliefSurface surface) {
    if (!surface.shouldShow || surface.evidencePhrases.isEmpty) {
      return surface;
    }
    final primary = surface.evidencePhrases.first.trim();
    if (primary.isEmpty) return surface;

    final display = displayLabelForGroundedPhrase(primary);
    return ArchiveBeliefSurface(
      shouldShow: surface.shouldShow,
      isPreview: surface.isPreview,
      headline: surface.headline,
      beliefSummary: ArchiveBeliefSurfaceCopy.beliefWithPhrase(display),
      evidenceSummary: surface.evidenceSummary,
      evidencePhrases: surface.evidencePhrases,
      whatChangedSummary: surface.whatChangedSummary,
      watchingNextLine: surface.watchingNextLine,
      confidenceLabel: surface.confidenceLabel,
      recordNextCta: surface.recordNextCta,
      isPrimaryAfterFirstProof: surface.isPrimaryAfterFirstProof,
      thread: surface.thread,
      preview: surface.preview,
    );
  }

  static bool _allowsPrompt(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return false;
    }
    return true;
  }
}
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the first proof moment after a third related save.
abstract final class FirstProofMomentEngine {
  FirstProofMomentEngine._();

  static FirstProofMoment? build({required List<JournalEntry> entries}) {
    if (!ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 3) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(eligible)) {
      return null;
    }

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      evidence.phrases,
      eligible,
    );
    final hasStrongEvidence = evidence.isStrong && grounded.isNotEmpty;
    final usesPhraseBody = hasStrongEvidence;

    return FirstProofMoment(
      primaryLabel: FirstProofMomentCopy.primaryLabel,
      title: usesPhraseBody
          ? FirstProofMomentCopy.title
          : FirstProofMomentCopy.titlePossible,
      body: usesPhraseBody
          ? FirstProofMomentCopy.bodyStrong
          : FirstProofMomentCopy.bodyFallback,
      evidenceLabel: FirstProofMomentCopy.evidenceLabel,
      evidencePhrases: usesPhraseBody ? grounded.take(3).toList() : const [],
      whyLine: FirstProofMomentCopy.whyLine,
      nextLine: FirstProofMomentCopy.nextLine,
      hasStrongEvidence: hasStrongEvidence,
      usesPhraseBody: usesPhraseBody,
    );
  }
}
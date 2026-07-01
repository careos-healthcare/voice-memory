import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_first_signal_engine.dart';
import 'first_proof_moment_copy.dart';
import 'first_proof_moment_model.dart';

/// Builds the first proof moment after a third related save.
abstract final class FirstProofMomentEngine {
  FirstProofMomentEngine._();

  static FirstProofMoment? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 3) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(eligible)) {
      return null;
    }

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    final phrases = evidence.phrases.take(3).toList();
    final primaryPhrase = phrases.isNotEmpty ? phrases.first : null;
    final usesPhraseBody = primaryPhrase != null &&
        ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(primaryPhrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(primaryPhrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: primaryPhrase,
          entries: eligible,
        );

    return FirstProofMoment(
      title: FirstProofMomentCopy.title,
      body: usesPhraseBody
          ? FirstProofMomentCopy.bodyWithPhrase(primaryPhrase)
          : FirstProofMomentCopy.bodyFallback,
      evidenceLabel: FirstProofMomentCopy.evidenceLabel,
      evidencePhrases: phrases,
      whyLine: FirstProofMomentCopy.whyLine,
      footer: FirstProofMomentCopy.footer,
      hasStrongEvidence: evidence.isStrong,
      usesPhraseBody: usesPhraseBody,
    );
  }
}

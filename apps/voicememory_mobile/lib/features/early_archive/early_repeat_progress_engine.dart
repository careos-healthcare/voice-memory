import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_repeat_progress_copy.dart';
import 'early_repeat_progress_model.dart';

/// Builds the early repeat progress card for entryCount 1–2.
abstract final class EarlyRepeatProgressEngine {
  EarlyRepeatProgressEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static EarlyRepeatProgressResult? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty || eligible.length > 2) return null;

    if (eligible.length == 1) {
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
        eligible.first,
      );
      return EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.oneMoment,
        title: EarlyRepeatProgressCopy.oneMomentTitle,
        body: EarlyRepeatProgressCopy.oneMomentBody,
        progressLabel: EarlyRepeatProgressCopy.oneMomentProgress,
        nextMomentCue: EarlyRepeatNextMomentCue(
          label: EarlyRepeatProgressCopy.oneMomentCueLabel,
          body: phrase != null
              ? EarlyRepeatProgressCopy.oneMomentCueBodyWithPhrase(phrase)
              : EarlyRepeatProgressCopy.oneMomentCueBodyFallback,
          footer: EarlyRepeatProgressCopy.oneMomentCueFooter,
        ),
      );
    }

    if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(eligible);
      return EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.twoRelated,
        title: EarlyRepeatProgressCopy.twoRelatedTitle,
        body: EarlyRepeatProgressCopy.twoRelatedBody,
        progressLabel: EarlyRepeatProgressCopy.twoRelatedProgress,
        nextMomentCue: EarlyRepeatNextMomentCue(
          label: EarlyRepeatProgressCopy.twoRelatedCueLabel,
          body: phrase != null
              ? EarlyRepeatProgressCopy.twoRelatedCueBodyWithPhrase(phrase)
              : EarlyRepeatProgressCopy.twoRelatedCueBodyFallback,
          footer: EarlyRepeatProgressCopy.twoRelatedCueFooter,
        ),
      );
    }

    return const EarlyRepeatProgressResult(
      kind: EarlyRepeatProgressKind.twoUnrelated,
      title: EarlyRepeatProgressCopy.twoUnrelatedTitle,
      body: EarlyRepeatProgressCopy.twoUnrelatedBody,
      progressLabel: EarlyRepeatProgressCopy.twoUnrelatedProgress,
      nextMomentCue: EarlyRepeatNextMomentCue(
        label: EarlyRepeatProgressCopy.twoUnrelatedCueLabel,
        body: EarlyRepeatProgressCopy.twoUnrelatedCueBody,
        footer: EarlyRepeatProgressCopy.twoUnrelatedCueFooter,
      ),
    );
  }
}

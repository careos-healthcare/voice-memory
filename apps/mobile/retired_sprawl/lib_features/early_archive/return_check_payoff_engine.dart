import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:archiveme_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_gates.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the return-check payoff after a fourth-or-later related save.
abstract final class ReturnCheckPayoffEngine {
  ReturnCheckPayoffEngine._();

  static ReturnCheckPayoff? build({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    if (entries.length < 4) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }
    if (!RepeatReturnCheckGates.hasRelatedRepeatSave(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final foundation = eligible.length >= 3 ? eligible.sublist(0, 3) : eligible;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(foundation);
    if (!evidence.isStrong) return null;

    final latestEntryId = RepeatReturnCheckStore.latestSavedEntryId(entries);
    final state = _resolveComparisonState(
      returnChecks: returnChecks,
      latestEntryId: latestEntryId,
    );

    final phrase = ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(
      foundation,
    );
    final usesPhraseBody =
        state != ReturnCheckPayoffComparisonState.unknown &&
        phrase != null &&
        ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: phrase,
          entries: foundation,
        );

    final (title, body, footer) = _copyFor(state, phrase, usesPhraseBody);

    return ReturnCheckPayoff(
      state: state,
      title: title,
      body: body,
      evidenceLabel: ReturnCheckPayoffCopy.evidenceLabel,
      footer: footer,
      hasPhrase: usesPhraseBody,
      hasConfirmedRepeat: true,
      usesPhraseBody: usesPhraseBody,
    );
  }

  static ReturnCheckPayoffComparisonState _resolveComparisonState({
    required List<RepeatReturnCheckRecord> returnChecks,
    required String latestEntryId,
  }) {
    final latestRecord = returnChecks
        .where((record) => record.entryId == latestEntryId)
        .firstOrNull;
    final latestChoice = latestRecord?.choice;

    if (latestChoice == null) {
      return ReturnCheckPayoffComparisonState.unknown;
    }

    if (latestChoice == RepeatReturnCheckChoice.changed) {
      return ReturnCheckPayoffComparisonState.changed;
    }

    return switch (latestChoice) {
      RepeatReturnCheckChoice.softer => ReturnCheckPayoffComparisonState.softer,
      RepeatReturnCheckChoice.stronger =>
        ReturnCheckPayoffComparisonState.stronger,
      RepeatReturnCheckChoice.same => ReturnCheckPayoffComparisonState.same,
      RepeatReturnCheckChoice.changed =>
        ReturnCheckPayoffComparisonState.changed,
    };
  }

  static (String title, String body, String footer) _copyFor(
    ReturnCheckPayoffComparisonState state,
    String? phrase,
    bool usesPhraseBody,
  ) => switch (state) {
    ReturnCheckPayoffComparisonState.softer => (
      ReturnCheckPayoffCopy.softerTitle,
      usesPhraseBody && phrase != null
          ? ReturnCheckPayoffCopy.softerBodyWithPhrase(phrase)
          : ReturnCheckPayoffCopy.softerBodyFallback,
      ReturnCheckPayoffCopy.softerFooter,
    ),
    ReturnCheckPayoffComparisonState.stronger => (
      ReturnCheckPayoffCopy.strongerTitle,
      usesPhraseBody && phrase != null
          ? ReturnCheckPayoffCopy.strongerBodyWithPhrase(phrase)
          : ReturnCheckPayoffCopy.strongerBodyFallback,
      ReturnCheckPayoffCopy.strongerFooter,
    ),
    ReturnCheckPayoffComparisonState.same => (
      ReturnCheckPayoffCopy.sameTitle,
      usesPhraseBody && phrase != null
          ? ReturnCheckPayoffCopy.sameBodyWithPhrase(phrase)
          : ReturnCheckPayoffCopy.sameBodyFallback,
      ReturnCheckPayoffCopy.sameFooter,
    ),
    ReturnCheckPayoffComparisonState.changed => (
      ReturnCheckPayoffCopy.changedTitle,
      usesPhraseBody && phrase != null
          ? ReturnCheckPayoffCopy.changedBodyWithPhrase(phrase)
          : ReturnCheckPayoffCopy.changedBodyFallback,
      ReturnCheckPayoffCopy.changedFooter,
    ),
    ReturnCheckPayoffComparisonState.unknown => (
      ReturnCheckPayoffCopy.unknownTitle,
      ReturnCheckPayoffCopy.unknownBody,
      ReturnCheckPayoffCopy.unknownFooter,
    ),
  };
}
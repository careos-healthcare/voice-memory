import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_check_answer_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_gates.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the post-save return check answer question at entry four+.
abstract final class PostSaveReturnCheckAnswerEngine {
  PostSaveReturnCheckAnswerEngine._();

  static PostSaveReturnCheckAnswer? build({
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
    final existing = returnChecks
        .where((record) => record.entryId == latestEntryId)
        .firstOrNull;
    if (existing?.choice != null) return null;

    final phrase = ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(
      foundation,
    );
    final usesPhraseBody =
        phrase != null &&
        ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: phrase,
          entries: foundation,
        );

    return PostSaveReturnCheckAnswer(
      entryId: latestEntryId,
      label: PostSaveReturnCheckAnswerCopy.label,
      title: PostSaveReturnCheckAnswerCopy.title,
      body: usesPhraseBody
          ? PostSaveReturnCheckAnswerCopy.bodyWithPhrase(phrase)
          : PostSaveReturnCheckAnswerCopy.bodyFallback,
      footer: PostSaveReturnCheckAnswerCopy.footer,
      hasPhrase: usesPhraseBody,
      hasConfirmedRepeat: true,
      entryCount: entries.length,
    );
  }
}
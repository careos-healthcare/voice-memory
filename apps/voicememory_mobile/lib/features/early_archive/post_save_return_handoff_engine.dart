import '../beta_improvement/beta_improvement_pack_engine.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'post_save_return_handoff_copy.dart';
import 'post_save_return_handoff_model.dart';

/// Builds the post-save return handoff after entry 1 or 2.
abstract final class PostSaveReturnHandoffEngine {
  PostSaveReturnHandoffEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static PostSaveReturnHandoff? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty || eligible.length > 2) return null;

    if (eligible.length == 1) {
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
        eligible.first,
      );
      return PostSaveReturnHandoff(
        stage: PostSaveReturnHandoffStage.afterFirstSave,
        relationState: PostSaveReturnHandoffRelationState.oneMoment,
        title: BetaImprovementPackEngine.postSaveReturnCue(
          entryCount: 1,
          fallback: PostSaveReturnHandoffCopy.afterFirstSaveTitle,
        ),
        body: phrase != null
            ? PostSaveReturnHandoffCopy.afterFirstSaveBodyWithPhrase(phrase)
            : PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
        footer: BetaImprovementPackEngine.returnOptionalFraming(entryCount: 1) ??
            PostSaveReturnHandoffCopy.afterFirstSaveFooter,
        hasPhrase: phrase != null,
      );
    }

    if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(eligible);
      return PostSaveReturnHandoff(
        stage: PostSaveReturnHandoffStage.afterSecondSaveRelated,
        relationState: PostSaveReturnHandoffRelationState.twoRelated,
        title: PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle,
        body: phrase != null
            ? PostSaveReturnHandoffCopy.afterSecondSaveRelatedBodyWithPhrase(
                phrase,
              )
            : PostSaveReturnHandoffCopy.afterSecondSaveRelatedBodyFallback,
        footer: PostSaveReturnHandoffCopy.afterSecondSaveRelatedFooter,
        hasPhrase: phrase != null,
      );
    }

    return const PostSaveReturnHandoff(
      stage: PostSaveReturnHandoffStage.afterSecondSaveUnrelated,
      relationState: PostSaveReturnHandoffRelationState.twoUnrelated,
      title: PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedTitle,
      body: PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedBody,
      footer: PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedFooter,
      hasPhrase: false,
    );
  }
}

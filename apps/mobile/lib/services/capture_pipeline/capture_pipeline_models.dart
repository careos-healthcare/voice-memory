import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:fpdart/fpdart.dart';

class CapturePipelineFailure implements Exception {
  CapturePipelineFailure(
    this.message, {
    this.savedDraft = false,
    this.entry,
    this.cause,
    this.innerException,
  });

  final String message;
  final bool savedDraft;
  final JournalEntry? entry;
  final Object? cause;
  final Object? innerException;

  @override
  String toString() => message;
}

enum PipelineStage { attesting, transcribing, analyzing, saving, done }

class CapturePipelineResult {
  const CapturePipelineResult({
    required this.entry,
    required this.localSaved,
    required this.syncSucceeded,
    this.analysisSucceeded = false,
    this.syncNote,
    this.attachedTypedTextToVoiceEntry = false,
    this.lowQualityTranscript = false,
  });

  final JournalEntry entry;
  final bool localSaved;
  final bool syncSucceeded;
  final bool analysisSucceeded;
  final String? syncNote;
  final bool attachedTypedTextToVoiceEntry;
  final bool lowQualityTranscript;
}

/// Successful capture pipeline completion — alias for [CapturePipelineResult].
typedef PipelineSuccess = CapturePipelineResult;

/// Functional result for capture pipeline operations.
typedef CapturePipelineOutcome = Either<CapturePipelineFailure, PipelineSuccess>;

typedef PostSaveMomentDetailOutcome = Either<CapturePipelineFailure, JournalEntry>;

Left<CapturePipelineFailure, PipelineSuccess> pipelineFailure(
  CapturePipelineFailure failure,
) => Left(failure);

Right<CapturePipelineFailure, PipelineSuccess> pipelineSuccess(
  PipelineSuccess success,
) => Right(success);

extension CapturePipelineOutcomeX on CapturePipelineOutcome {
  PipelineSuccess getOrThrow() => match(
    (failure) => throw failure,
    (success) => success,
  );

  Future<void> whenFailed(void Function(CapturePipelineFailure failure) action) =>
      match(
        (failure) async => action(failure),
        (_) async {},
      );
}

extension PostSaveMomentDetailOutcomeX on PostSaveMomentDetailOutcome {
  JournalEntry getOrThrow() => match(
    (failure) => throw failure,
    (entry) => entry,
  );
}

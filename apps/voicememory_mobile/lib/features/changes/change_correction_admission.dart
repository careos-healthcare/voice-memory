import 'change_thread.dart';

enum ChangeMergeRefusal {
  noSubjectOverlap,
  incompatibleSuppression,
  archiveMismatch,
}

class ChangeMergeAdmission {
  const ChangeMergeAdmission._({
    required this.allowed,
    required this.resultingLabel,
    this.refusal,
  });

  final bool allowed;
  final ChangeMergeRefusal? refusal;
  final String resultingLabel;

  String? get refusalMessage => switch (refusal) {
    ChangeMergeRefusal.noSubjectOverlap =>
      'These threads do not share a subject, so they cannot be merged.',
    ChangeMergeRefusal.incompatibleSuppression =>
      'These threads have incompatible hidden-reading choices.',
    ChangeMergeRefusal.archiveMismatch =>
      'Threads from different archives cannot be merged.',
    null => null,
  };

  static ChangeMergeAdmission allow(String resultingLabel) =>
      ChangeMergeAdmission._(allowed: true, resultingLabel: resultingLabel);

  static ChangeMergeAdmission refuse(ChangeMergeRefusal refusal) =>
      ChangeMergeAdmission._(
        allowed: false,
        refusal: refusal,
        resultingLabel: '',
      );
}

/// Durable admission rules shared by the confirmation UI and correction replay.
abstract final class ChangeCorrectionAdmission {
  ChangeCorrectionAdmission._();

  static ChangeMergeAdmission merge(ChangeThread source, ChangeThread into) {
    if (source.archiveId != into.archiveId) {
      return ChangeMergeAdmission.refuse(ChangeMergeRefusal.archiveMismatch);
    }
    final sourceSuppressed =
        source.visibilityState == ChangeThreadVisibility.suppressed ||
        source.correctionState == ChangeThreadCorrectionState.framingSuppressed;
    final intoSuppressed =
        into.visibilityState == ChangeThreadVisibility.suppressed ||
        into.correctionState == ChangeThreadCorrectionState.framingSuppressed;
    if (sourceSuppressed != intoSuppressed) {
      return ChangeMergeAdmission.refuse(
        ChangeMergeRefusal.incompatibleSuppression,
      );
    }
    if (source.subjectRepresentation
        .intersection(into.subjectRepresentation)
        .isEmpty) {
      return ChangeMergeAdmission.refuse(ChangeMergeRefusal.noSubjectOverlap);
    }

    // A label the user explicitly chose outranks an inferred destination label.
    final resultingLabel =
        into.labelIsUserConfirmed || !source.labelIsUserConfirmed
        ? into.userEditableLabel
        : source.userEditableLabel;
    return ChangeMergeAdmission.allow(resultingLabel);
  }
}

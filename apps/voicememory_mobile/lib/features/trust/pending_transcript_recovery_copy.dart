/// Copy for repairing pending-transcript voice moments with typed text.
abstract final class PendingTranscriptRecoveryCopy {
  PendingTranscriptRecoveryCopy._();

  static const title = 'Transcript pending';
  static const body =
      'This moment is saved, but ArchiveMe cannot compare it yet.';

  static const primaryAction = 'Add what you said';
  static const helper = 'One short sentence is enough.';

  /// Record post-save recovery card — one calm path after degraded voice save.
  static const postSaveTitle = 'Saved, but ArchiveMe could not hear enough.';
  static const postSaveBody =
      'Add one short sentence so ArchiveMe can compare this moment later.';
  static const moreOptionsLabel = 'More options';
  static const bluetoothAccessoryNote =
      'If this keeps happening, disconnect Bluetooth or audio accessories and try again.';

  static const inputTitle = 'What did you say?';
  static const inputHelper = 'Add the part ArchiveMe should use as evidence.';

  static const saveButton = 'Save text';
  static const cancelButton = 'Cancel';

  static const savedSuccess = 'Text saved.';
  static const saveFailed = 'That text was not saved. Please try again.';

  static const List<String> all = [
    title,
    body,
    primaryAction,
    helper,
    postSaveTitle,
    postSaveBody,
    moreOptionsLabel,
    bluetoothAccessoryNote,
    inputTitle,
    inputHelper,
    saveButton,
    cancelButton,
    savedSuccess,
    saveFailed,
  ];
}

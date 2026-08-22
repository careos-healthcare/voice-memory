/// Copy for the early Record saved-moments review sheet.
abstract final class EarlySavedMomentsCopy {
  EarlySavedMomentsCopy._();

  static const viewSavedMomentsCta = 'View saved moments';

  static const sheetTitle = 'Saved moments';
  static const sheetSubtitle = 'ArchiveMe uses these to look for a repeat.';

  static const savedMomentsSectionTitle = 'Saved moments';
  static const comparingSectionTitle = 'What ArchiveMe is comparing';
  static const nextRecordSectionTitle = 'What to record next';

  static const momentLabelPrefix = 'Moment';

  static const comparingRelated =
      'These moments look related enough for ArchiveMe to keep watching.';
  static const comparingNoClearMatch =
      'ArchiveMe is still looking for a clearer match.';

  static const nextActionOneEntry = 'Come back when something similar happens.';
  static const nextActionTwoUnrelated =
      'Record the next real moment. No need to force a pattern.';
  static const nextActionTwoRelated =
      'One more related moment unlocks first proof.';
}
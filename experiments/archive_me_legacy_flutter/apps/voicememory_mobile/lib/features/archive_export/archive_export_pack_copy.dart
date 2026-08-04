/// User-facing copy for the local Archive Export Pack.
abstract final class ArchiveExportPackCopy {
  ArchiveExportPackCopy._();

  static const screenTitle = 'Export archive';

  static const reviewBeforeSharing = 'Review before sharing.';

  static const emptyTitle = 'Nothing to export yet';

  static const emptyBody =
      'Save a moment on this device first. Your export will appear here when '
      'your archive has something to include.';

  static const previewIntro =
      'This is a private summary from ArchiveMe on this device. Tap Share '
      'export only when you are ready.';

  static const proBoundaryTitle = 'Export the longer trail';

  static const proBoundaryBody =
      'Free shows the first useful proof. Pro keeps the longer trail.';

  static const headerTitle = 'ArchiveMe private archive export';

  static const exportDateLabel = 'Export date';

  static const savedMomentsLabel = 'Saved moments';

  static const usableEvidenceLabel = 'Usable evidence moments';

  static const currentBeliefLabel = 'Current archive belief';

  static const evidenceMapLabel = 'Evidence map summary';

  static const weeklyReviewLabel = 'Weekly review summary';

  static const recentMomentsLabel = 'Recent saved moments';

  static const privacyNoteDevice = 'This export was created on this device.';

  static const privacyNoteReview = 'Review before sharing.';

  static const shareExportCta = 'Share export';

  static const sharingCta = 'Sharing…';

  static const shareSubject = 'ArchiveMe archive export';

  static const previewUnavailable =
      'Saved locally — preview not available yet.';

  static String evidenceMapRow(String label, int count) =>
      '$label: $count ${count == 1 ? 'moment' : 'moments'}';

  static const notEnoughBeliefYet = 'Not enough evidence yet';
}

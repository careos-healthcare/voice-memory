import 'package:archiveme_mobile/features/archive_evidence/transcript_pending_copy.dart';

/// User-facing copy for the saved moment detail screen.
abstract class EntryDetailCopy {
  EntryDetailCopy._();

  static const String title = 'Saved moment';
  static const String whatYouRecorded = 'What you recorded';
  static const String archiveNoteLabel = 'Archive note';
  static const String archiveNoteBody =
      'This moment is part of your private archive.';
  static const String archiveNoteHelper =
      'ArchiveMe can compare it with future entries when there is enough to compare.';
  static const String transcriptPending =
      TranscriptPendingCopy.transcriptPendingTitle;
  static const String transcriptPendingBody =
      TranscriptPendingCopy.transcriptPendingBody;
  static const String advancedDetails = 'Advanced entry details';
  static const String delete = 'Delete';
  static const String deleteConfirmTitle = 'Delete this moment?';
  static const String deleteConfirmBody =
      'This removes it from your archive on this device.';

  static const List<String> all = [
    title,
    whatYouRecorded,
    archiveNoteLabel,
    archiveNoteBody,
    archiveNoteHelper,
    transcriptPending,
    transcriptPendingBody,
    advancedDetails,
    delete,
    deleteConfirmTitle,
    deleteConfirmBody,
  ];
}
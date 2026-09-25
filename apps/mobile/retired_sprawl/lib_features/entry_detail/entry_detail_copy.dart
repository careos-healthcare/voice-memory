import 'package:archiveme_mobile/features/archive_evidence/transcript_pending_copy.dart';

/// User-facing copy for the saved moment detail screen.
abstract class EntryDetailCopy {
  EntryDetailCopy._();

  static const String title = 'Saved moment';
  static const String whatYouRecorded = 'What you recorded';
  static const String audioMissing = "Original audio isn't on this device";
  static const String editDateTime = 'Edit date and time';
  static const String readAloud = 'Read aloud';
  static const String titleField = 'Title';
  static const String transcriptPending =
      TranscriptPendingCopy.transcriptPendingTitle;
  static const String transcriptPendingBody =
      TranscriptPendingCopy.transcriptPendingBody;
  static const String advancedDetails = 'More';
  static const String delete = 'Delete';
  static const String deleteConfirmTitle = 'Delete this moment?';
  static const String deleteConfirmBody =
      'This removes it from your archive on this device.';

  static const List<String> all = [
    title,
    whatYouRecorded,
    audioMissing,
    editDateTime,
    readAloud,
    titleField,
    transcriptPending,
    transcriptPendingBody,
    advancedDetails,
    delete,
    deleteConfirmTitle,
    deleteConfirmBody,
  ];
}
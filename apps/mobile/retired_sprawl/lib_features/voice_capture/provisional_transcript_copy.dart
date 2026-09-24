/// User-facing copy when native offline STT produced a draft transcript.
abstract final class ProvisionalTranscriptCopy {
  ProvisionalTranscriptCopy._();

  static const chipLabel = 'Draft transcript';

  static const detailFootnote =
      'This transcript came from your device. Thoughtprint will refine it when connected.';

  static const historyNote =
      'Thoughtprint will refine this transcript when connected.';

  static const postSaveFootnote =
      'Thoughtprint will refine this transcript when connected.';
}
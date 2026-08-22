import 'package:archiveme_mobile/features/correction_memory/correction_memory_model.dart';

/// Copy for saved archive corrections — user trust layer only.
abstract final class CorrectionMemoryCopy {
  CorrectionMemoryCopy._();

  static const title = 'Archive correction saved';

  static const stillCurrentBody =
      'You marked this as still affecting you. ArchiveMe will treat fresh returns '
      'as stronger evidence.';

  static const partlyCurrentBody =
      'You marked this as only partly current. ArchiveMe will keep it in view, '
      'but not treat it as the whole story.';

  static const fadedBody =
      'You marked this as not really current. ArchiveMe will treat it as background '
      'unless it returns.';

  static const unsureBody =
      'You were not sure. ArchiveMe will keep this lightly in view and wait for '
      'stronger evidence.';

  static const returnedAfterFadedBody =
      'This returned after you marked it as background.';

  static const returnedAfterFadedEvidenceLine =
      'This returned after you marked it as background.';

  static const footer =
      'You can correct the archive. Your past is context, not a verdict.';

  static const differentiationLine =
      'ChatGPT responds in the moment. ArchiveMe remembers how you corrected the timeline.';

  static String bodyFor(CorrectionMemoryState state) => switch (state) {
    CorrectionMemoryState.stillCurrent => stillCurrentBody,
    CorrectionMemoryState.partlyCurrent => partlyCurrentBody,
    CorrectionMemoryState.faded => fadedBody,
    CorrectionMemoryState.unsure => unsureBody,
  };

  static const List<String> all = [
    title,
    stillCurrentBody,
    partlyCurrentBody,
    fadedBody,
    unsureBody,
    returnedAfterFadedBody,
    returnedAfterFadedEvidenceLine,
    footer,
    differentiationLine,
  ];
}
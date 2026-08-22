import 'package:archiveme_mobile/features/moment_quality/moment_quality_models.dart';

/// User-facing copy for the moment quality coach — no scores or pressure.
abstract final class MomentQualityCopy {
  MomentQualityCopy._();

  static const helperLabel = 'Make this more useful later';

  static const veryShortTitle = 'This is enough to save.';
  static const veryShortBody =
      'Add one detail if you want ArchiveMe to compare it later.';
  static const veryShortSuggestions = [
    'What happened?',
    'Where did it show up?',
    'What did you notice?',
  ];

  static const someDetailTitle = 'Useful start.';
  static const someDetailBody =
      'One more detail can make this easier to compare later.';
  static const someDetailSuggestions = [
    'Add the situation.',
    'Add what changed.',
    'Add what made it stand out.',
  ];

  static const strongDetailTitle = 'Good archive evidence.';
  static const strongDetailBody =
      'This gives ArchiveMe something clearer to compare later.';

  static MomentQualityResult resultFor(MomentQualityLevel level) {
    switch (level) {
      case MomentQualityLevel.veryShort:
        return const MomentQualityResult(
          level: MomentQualityLevel.veryShort,
          title: veryShortTitle,
          body: veryShortBody,
          suggestions: veryShortSuggestions,
        );
      case MomentQualityLevel.someDetail:
        return const MomentQualityResult(
          level: MomentQualityLevel.someDetail,
          title: someDetailTitle,
          body: someDetailBody,
          suggestions: someDetailSuggestions,
        );
      case MomentQualityLevel.strongDetail:
        return const MomentQualityResult(
          level: MomentQualityLevel.strongDetail,
          title: strongDetailTitle,
          body: strongDetailBody,
        );
    }
  }

  static Iterable<String> allVisibleCopy() sync* {
    yield helperLabel;
    yield veryShortTitle;
    yield veryShortBody;
    yield* veryShortSuggestions;
    yield someDetailTitle;
    yield someDetailBody;
    yield* someDetailSuggestions;
    yield strongDetailTitle;
    yield strongDetailBody;
  }
}
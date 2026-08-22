import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// Safe confidence copy for pattern match quality — no private text.
abstract final class PatternMatchQualityCopy {
  PatternMatchQualityCopy._();

  static const weak = 'ArchiveMe is only watching this for now.';

  static const emerging = 'This may be starting to repeat.';

  static const solid = 'This has returned in more than one saved moment.';

  static const strong = 'This has a clear timeline now.';

  static const watchOnlySubtitle =
      'ArchiveMe is watching this lightly until the overlap is clearer.';

  static const List<String> all = [
    weak,
    emerging,
    solid,
    strong,
    watchOnlySubtitle,
  ];

  static String explanationFor(PatternMatchConfidenceBand band) =>
      switch (band) {
        PatternMatchConfidenceBand.weak => weak,
        PatternMatchConfidenceBand.emerging => emerging,
        PatternMatchConfidenceBand.solid => solid,
        PatternMatchConfidenceBand.strong => strong,
      };
}
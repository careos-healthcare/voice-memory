import 'package:archiveme_mobile/features/first_session/first_session_pattern_engine.dart' show FirstSessionPatternEngine;

/// Canonical first-session pattern titles from [FirstSessionPatternEngine].
abstract class FirstPatternQualityTitles {
  FirstPatternQualityTitles._();

  static const responsibility = 'Taking responsibility before asking for help';
  static const worry = 'The same worry returning';
  static const relationship = 'Carrying tension with someone';
  static const selfDoubt = 'Trying to prove you are enough';
  static const avoidance = 'Putting off what matters';
  static const burnout = 'Running on empty';
  static const fallback = 'Something worth watching';
  static const lighter = 'Something felt lighter today';

  static const List<String> all = [
    responsibility,
    worry,
    relationship,
    selfDoubt,
    avoidance,
    burnout,
    fallback,
    lighter,
  ];

  static const List<String> fallbackTitles = [fallback, lighter];

  static List<String> unacceptableFor(String categoryId) {
    return switch (categoryId) {
      'responsibility' => [worry, relationship, selfDoubt, avoidance, burnout],
      'worry' => [responsibility, relationship, selfDoubt, avoidance, burnout],
      'relationship' => [responsibility, worry, selfDoubt, avoidance, burnout],
      'selfDoubt' => [responsibility, worry, relationship, avoidance, burnout],
      'avoidance' => [responsibility, worry, relationship, selfDoubt, burnout],
      'burnout' => [responsibility, worry, relationship, selfDoubt, avoidance],
      _ => const [],
    };
  }
}
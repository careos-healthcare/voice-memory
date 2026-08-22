import 'package:archiveme_mobile/features/first_session/first_pattern_quality_result.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_sample.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_titles.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Runs labeled reflections through [FirstSessionPatternEngine] for QA.
class FirstPatternQualityRunner {
  const FirstPatternQualityRunner({FirstSessionPatternEngine? engine})
    : _engine = engine ?? const FirstSessionPatternEngine();

  final FirstSessionPatternEngine _engine;

  static const double lowConfidenceThreshold = 0.45;

  FirstPatternQualityResult run(List<FirstPatternQualitySample> samples) {
    var accepted = 0;
    var rejected = 0;
    var fallbackCount = 0;
    var lowConfidenceCount = 0;
    var correctionRecommendedCount = 0;
    var overconfidentWrongCount = 0;
    var vagueFallbackAcceptedCount = 0;
    var negationHandledCount = 0;
    var ambiguousHandledCount = 0;
    var vagueNeutralSampleCount = 0;
    var ambiguousSampleCount = 0;
    var negationSampleCount = 0;
    final categoryBreakdown = <String, int>{};
    final failures = <FirstPatternQualityFailure>[];

    for (final sample in samples) {
      final pattern = _engine.build(_entry(sample.reflectionText));
      final isAccepted = _isAccepted(sample, pattern);
      final isRejected = _isRejected(sample, pattern, isAccepted);

      if (sample.isVagueOrNeutral) vagueNeutralSampleCount++;
      if (sample.isAmbiguous) ambiguousSampleCount++;
      if (sample.isNegation) negationSampleCount++;

      if (isAccepted) {
        accepted++;
        categoryBreakdown[sample.expectedCategory] =
            (categoryBreakdown[sample.expectedCategory] ?? 0) + 1;
      }
      if (isRejected) {
        rejected++;
        if (pattern.confidenceScore >=
            FirstPatternQualityResult.overconfidentThreshold) {
          overconfidentWrongCount++;
        }
        failures.add(
          FirstPatternQualityFailure(
            sampleId: sample.id,
            reflectionText: sample.reflectionText,
            expectedCategory: sample.expectedCategory,
            actualTitle: pattern.title,
            confidenceScore: pattern.confidenceScore,
            matchReason: pattern.matchReason,
          ),
        );
      }

      if (_isFallbackTitle(pattern.title)) fallbackCount++;
      if (pattern.confidenceScore < lowConfidenceThreshold) {
        lowConfidenceCount++;
      }
      if (pattern.alternativePatterns.isNotEmpty || pattern.userCanCorrect) {
        correctionRecommendedCount++;
      }

      if (sample.isVagueOrNeutral && isAccepted && _isSoftLanding(pattern)) {
        vagueFallbackAcceptedCount++;
      }
      if (sample.isNegation && isAccepted) negationHandledCount++;
      if (sample.isAmbiguous && _ambiguousHandled(pattern)) {
        ambiguousHandledCount++;
      }
    }

    final total = samples.length;
    final accuracyRate = total == 0 ? 0.0 : accepted / total;

    return FirstPatternQualityResult(
      total: total,
      accepted: accepted,
      rejected: rejected,
      fallbackCount: fallbackCount,
      lowConfidenceCount: lowConfidenceCount,
      correctionRecommendedCount: correctionRecommendedCount,
      accuracyRate: accuracyRate,
      categoryBreakdown: categoryBreakdown,
      failures: failures,
      overconfidentWrongCount: overconfidentWrongCount,
      vagueFallbackAcceptedCount: vagueFallbackAcceptedCount,
      negationHandledCount: negationHandledCount,
      ambiguousHandledCount: ambiguousHandledCount,
      vagueNeutralSampleCount: vagueNeutralSampleCount,
      ambiguousSampleCount: ambiguousSampleCount,
      negationSampleCount: negationSampleCount,
    );
  }

  bool _isFallbackTitle(String title) =>
      FirstPatternQualityTitles.fallbackTitles.contains(title);

  bool _isSoftLanding(FirstSessionPattern pattern) =>
      _isFallbackTitle(pattern.title) ||
      pattern.isLighterMoment ||
      pattern.isLowConfidence;

  bool _ambiguousHandled(FirstSessionPattern pattern) =>
      pattern.isAmbiguousMatch ||
      pattern.isLowConfidence ||
      pattern.alternativePatterns.isNotEmpty ||
      pattern.userCanCorrect;

  bool _isAccepted(
    FirstPatternQualitySample sample,
    FirstSessionPattern pattern,
  ) {
    if (sample.acceptableTitles.contains(pattern.title)) return true;
    return sample.expectedCategory == pattern.categoryId &&
        sample.acceptableTitles.isEmpty;
  }

  bool _isRejected(
    FirstPatternQualitySample sample,
    FirstSessionPattern pattern,
    bool isAccepted,
  ) {
    if (sample.unacceptableTitles.contains(pattern.title)) return true;
    return !isAccepted;
  }

  JournalEntry _entry(String text) {
    return JournalEntry(
      id: 'qa-entry',
      createdAt: DateTime(2026, 5, 25),
      transcript: text,
      durationSeconds: 30,
      reflection: Reflection(
        mood: '',
        emotionalIntensity: 3,
        recurringThemes: const [],
        exactLanguagePattern: text,
        concreteObservation: text,
        repeatedSignal: text,
      ),
    );
  }
}
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:archiveme_mobile/features/language/language_model.dart';
import 'package:archiveme_mobile/features/language/localized_copy.dart';
import 'package:archiveme_mobile/features/tomorrow_return/compelling_check_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/compelling_check_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/result_next_check_model.dart';

/// Turns a closed-loop result into one useful next check.
///
/// The goal is to make the result feel actionable: people who close the loop
/// but do not choose a next check get a clear, concrete thing to carry into
/// tomorrow.
abstract class ResultNextCheckEngine {
  ResultNextCheckEngine._();

  static const String _ctaLabel = 'Use this tomorrow';

  /// Builds the next useful check for a completed check-in.
  ///
  /// [resultHint] accepts either the short hint (`same`, `lighter`, `heavier`,
  /// `changed`) or the stored option id (`showed_up_again`, `not_today`,
  /// `none_fit`, ...). [notUsefulReason] tailors the result when the user
  /// previously said the result was not useful.
  static ResultNextCheck build({
    required String resultHint,
    String? checkInQuestion,
    String? reflectionText,
    String? notUsefulReason,
    String? patternMemoryNote,
    String? patternProgressNote,
    String? patternTitle,
    ArchiveFeedbackType? feedback,
    ArchiveFeedbackSummary? feedbackSummary,
    String languageCode = 'en',
    bool preferDirect = false,
  }) {
    // A gentle nudge: feedback only fills in a reason when none was set, so an
    // explicit "not useful" complaint always wins over a feedback chip.
    final feedbackType = feedback ?? feedbackSummary?.dominantIssue;
    final effectiveReason =
        notUsefulReason ?? _reasonFromFeedback(feedbackType);

    // Non-English reflections get a localized next-check. English is unchanged.
    if (languageCode != 'en' && isSupportedLanguage(languageCode)) {
      return _localized(
        resultHint: resultHint,
        notUsefulReason: effectiveReason,
        languageCode: languageCode,
      );
    }

    // "Too vague" overrides the result type: the next check must point to a
    // single moment rather than the whole day.
    if (effectiveReason == 'too_vague') {
      return const ResultNextCheck(
        type: ResultNextCheckType.makeConcrete,
        title: 'Make the next check more concrete',
        whyUseful:
            'A useful check should point to one moment, not the whole day.',
        nextQuestion: 'What was the exact moment this showed up?',
        exampleMoment: 'It showed up when I opened the message.',
        ctaLabel: _ctaLabel,
      );
    }

    final base = _baseForHint(_normalizeHint(resultHint));
    final why = _whyUsefulWithReason(base.whyUseful, effectiveReason);
    final merged = why == base.whyUseful
        ? base
        : ResultNextCheck(
            type: base.type,
            title: base.title,
            whyUseful: why,
            nextQuestion: base.nextQuestion,
            exampleMoment: base.exampleMoment,
            ctaLabel: base.ctaLabel,
          );
    return _withCompelling(
      merged,
      resultHint: resultHint,
      checkInQuestion: checkInQuestion,
      patternTitle: patternTitle,
      feedback: feedbackType,
      feedbackSummary: feedbackSummary,
      preferDirect: preferDirect,
    );
  }

  /// Sharpens [base] through [buildCompellingCheck] for English next checks.
  static ResultNextCheck _withCompelling(
    ResultNextCheck base, {
    required String resultHint,
    String? checkInQuestion,
    String? patternTitle,
    ArchiveFeedbackType? feedback,
    ArchiveFeedbackSummary? feedbackSummary,
    bool preferDirect = false,
  }) {
    final compelling = buildCompellingCheck(
      baseQuestion: base.nextQuestion,
      patternTitle: patternTitle,
      resultHint: resultHint,
      feedback: feedback,
      feedbackSummary: feedbackSummary,
      preferDirect: preferDirect,
      sharpnessLabel: defaultCompellingSharpnessLabel(
        feedback: feedback,
        feedbackSummary: feedbackSummary,
        preferDirect: preferDirect,
      ),
    );
    return ResultNextCheck(
      type: base.type,
      title: base.title,
      whyUseful: compelling.whyThisCheck,
      nextQuestion: compelling.question,
      exampleMoment: compelling.exampleAnswer,
      ctaLabel: base.ctaLabel,
    );
  }

  /// Chooser options for the post-save next-check card.
  static Map<String, CompellingCheckQuestion> compellingOptions({
    required String resultHint,
    String? checkInQuestion,
    String? patternTitle,
    ArchiveFeedbackType? feedback,
    ArchiveFeedbackSummary? feedbackSummary,
    bool preferDirect = false,
  }) {
    final base = build(
      resultHint: resultHint,
      checkInQuestion: checkInQuestion,
      patternTitle: patternTitle,
      feedback: feedback,
      feedbackSummary: feedbackSummary,
      preferDirect: preferDirect,
    );
    return buildCompellingCheckOptions(
      baseQuestion: base.nextQuestion,
      patternTitle: patternTitle,
      resultHint: resultHint,
      feedback: feedback,
      feedbackSummary: feedbackSummary,
      preferDirect: preferDirect,
    );
  }

  static ResultNextCheck _localized({
    required String resultHint,
    required String? notUsefulReason,
    required String languageCode,
  }) {
    String t(String key) => localized(key, languageCode);
    final cta = t('useThisTomorrow');
    if (notUsefulReason == 'too_vague') {
      return ResultNextCheck(
        type: ResultNextCheckType.makeConcrete,
        title: t('result.concrete.headline'),
        whyUseful: t('result.concrete.why'),
        nextQuestion: t('result.concreteNextCheck'),
        exampleMoment: t('result.concrete.example'),
        ctaLabel: cta,
      );
    }
    final hint = _normalizeHint(resultHint);
    return ResultNextCheck(
      type: _typeForHint(hint),
      title: t('result.$hint.headline'),
      whyUseful: t('result.$hint.why'),
      nextQuestion: t('result.$hint.nextCheck'),
      exampleMoment: t('result.$hint.example'),
      ctaLabel: cta,
    );
  }

  static ResultNextCheckType _typeForHint(String hint) {
    switch (hint) {
      case 'lighter':
        return ResultNextCheckType.findHelped;
      case 'heavier':
        return ResultNextCheckType.reduceHeavier;
      case 'changed':
        return ResultNextCheckType.noticeDifferent;
      case 'same':
      default:
        return ResultNextCheckType.repeatBefore;
    }
  }

  static String _normalizeHint(String resultHint) {
    switch (resultHint) {
      case 'same':
      case 'showed_up_again':
        return 'same';
      case 'lighter':
        return 'lighter';
      case 'heavier':
        return 'heavier';
      case 'changed':
      case 'not_today':
      case 'none_fit':
        return 'changed';
      default:
        return 'same';
    }
  }

  static ResultNextCheck _baseForHint(String hint) {
    switch (hint) {
      case 'lighter':
        return const ResultNextCheck(
          type: ResultNextCheckType.findHelped,
          title: 'Check what helped',
          whyUseful: 'If it felt lighter, something may have helped today.',
          nextQuestion: 'What helped make it lighter?',
          exampleMoment: 'It felt lighter after I paused.',
          ctaLabel: _ctaLabel,
        );
      case 'heavier':
        return const ResultNextCheck(
          type: ResultNextCheckType.reduceHeavier,
          title: 'Check what made it heavier',
          whyUseful:
              'If it felt heavier, the useful part is finding what added pressure.',
          nextQuestion: 'What made it heavier?',
          exampleMoment: 'It felt heavier after I took it on alone.',
          ctaLabel: _ctaLabel,
        );
      case 'changed':
        return const ResultNextCheck(
          type: ResultNextCheckType.noticeDifferent,
          title: 'Check what changed',
          whyUseful:
              'If today was different, that may show what moves the pattern.',
          nextQuestion: 'What was different today?',
          exampleMoment: 'It changed when I waited before answering.',
          ctaLabel: _ctaLabel,
        );
      case 'same':
      default:
        return const ResultNextCheck(
          type: ResultNextCheckType.repeatBefore,
          title: 'Check what happens before it starts',
          whyUseful:
              'If it keeps showing up, the useful part is noticing the moment before it begins.',
          nextQuestion: 'What happens right before it shows up?',
          exampleMoment: 'I noticed it started before I said yes.',
          ctaLabel: _ctaLabel,
        );
    }
  }

  /// Maps a feedback chip to the closest existing "not useful" reason so the
  /// next check shifts gently:
  /// - too generic / more specific → point at one concrete moment
  /// - already knew → emphasize change over time
  static String? _reasonFromFeedback(ArchiveFeedbackType? feedback) {
    switch (feedback) {
      case ArchiveFeedbackType.tooGeneric:
      case ArchiveFeedbackType.moreSpecific:
        return 'too_vague';
      case ArchiveFeedbackType.alreadyKnew:
        return 'already_knew_this';
      case ArchiveFeedbackType.useful:
      case ArchiveFeedbackType.notMe:
      case null:
        return null;
    }
  }

  static String _whyUsefulWithReason(String base, String? notUsefulReason) {
    switch (notUsefulReason) {
      case 'already_knew_this':
        return '$base The value is not that it happened once. '
            'The value is whether it keeps happening or changes.';
      case 'confusing':
        return '$base Keep tomorrow\u2019s answer simple: what happened, '
            'and whether it felt lighter, heavier, or different.';
      default:
        return base;
    }
  }
}
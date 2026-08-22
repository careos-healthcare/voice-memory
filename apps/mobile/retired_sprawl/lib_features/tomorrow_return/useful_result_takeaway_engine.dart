import 'package:archiveme_mobile/features/language/language_model.dart';
import 'package:archiveme_mobile/features/language/localized_copy.dart';
import 'package:archiveme_mobile/features/tomorrow_return/useful_result_takeaway_model.dart';

/// Confidence label shown when the reflection is empty or very short.
const String _earlyReadLabel = 'Early read';

/// A reflection shorter than this (after trimming) is treated as thin.
const int _shortReflectionLength = 12;

/// Turns a closed-loop result into one useful takeaway.
///
/// The goal is to make the result feel useful *before* the usefulness rating:
/// a clear one-line takeaway, what it means, why it matters, and one next check.
/// [notUsefulReason] sharpens the takeaway when the user has said the result
/// was not useful.
UsefulResultTakeaway buildUsefulResultTakeaway({
  required String resultHint,
  required String checkInQuestion,
  String? reflectionText,
  String? notUsefulReason,
  bool inputQualityWeak = false,
  String languageCode = 'en',
}) {
  // Non-English reflections get a localized takeaway. English keeps the exact
  // original copy so existing flows are byte-for-byte unchanged.
  if (languageCode != 'en' && isSupportedLanguage(languageCode)) {
    return _localizedTakeaway(
      resultHint: resultHint,
      reflectionText: reflectionText,
      notUsefulReason: notUsefulReason,
      inputQualityWeak: inputQualityWeak,
      languageCode: languageCode,
    );
  }

  final thinReflection = _isThin(reflectionText);
  // Weak/too-short input is an early read too: don't overclaim the result.
  final earlyRead = thinReflection || inputQualityWeak;

  // "Too vague" overrides the result type: the next check must point to one
  // exact moment rather than the whole day.
  if (notUsefulReason == 'too_vague') {
    return UsefulResultTakeaway(
      type: UsefulResultTakeawayType.concrete,
      headline: 'Make this more concrete.',
      whatItMeans: 'The next check should point to one moment.',
      whyUseful: _withWeak(
        _withThin(
          'One clear moment is easier to compare tomorrow.',
          thinReflection,
        ),
        inputQualityWeak,
      ),
      nextCheck: 'What exact moment did this show up?',
      example: 'It showed up when I opened the message.',
      confidenceLabel: earlyRead ? _earlyReadLabel : null,
    );
  }

  final base = _baseForHint(_normalizeHint(resultHint));
  final whyUseful = _withWeak(
    _withReason(_withThin(base.whyUseful, thinReflection), notUsefulReason),
    inputQualityWeak,
  );

  return UsefulResultTakeaway(
    type: base.type,
    headline: base.headline,
    whatItMeans: base.whatItMeans,
    whyUseful: whyUseful,
    // On weak input, point at one exact moment instead of the broad next check.
    nextCheck: inputQualityWeak
        ? 'What exact moment did this show up?'
        : base.nextCheck,
    example: base.example,
    confidenceLabel: earlyRead ? _earlyReadLabel : null,
  );
}

/// Appends the weak-input nudge when the reflection was vague or too short.
String _withWeak(String base, bool inputQualityWeak) {
  if (!inputQualityWeak) return base;
  return '$base Add one clearer moment to make this more useful.';
}

/// A null reflection means "not provided" and is left unflagged. An empty or
/// very short reflection is treated as thin and earns an "Early read" label.
bool _isThin(String? reflectionText) {
  if (reflectionText == null) return false;
  return reflectionText.trim().length < _shortReflectionLength;
}

/// Appends the "add one more moment" nudge when the reflection is thin.
String _withThin(String base, bool thinReflection) {
  if (!thinReflection) return base;
  return '$base Add one more moment to make this clearer.';
}

/// Sharpens "why useful" based on the most recent not-useful complaint.
String _withReason(String base, String? notUsefulReason) {
  switch (notUsefulReason) {
    case 'already_knew_this':
      return '$base The value is not that it happened once. '
          'The value is whether it keeps happening or changes.';
    case 'not_accurate':
      return '$base Choose the closest answer, then record one moment so '
          'tomorrow can compare better.';
    case 'confusing':
      return '$base Keep it simple: what happened, and whether it felt '
          'lighter, heavier, or different.';
    default:
      return base;
  }
}

/// Localized variant of the takeaway for supported non-English languages.
UsefulResultTakeaway _localizedTakeaway({
  required String resultHint,
  required String? reflectionText,
  required String? notUsefulReason,
  required bool inputQualityWeak,
  required String languageCode,
}) {
  String t(String key) => localized(key, languageCode);
  final earlyRead = _isThin(reflectionText) || inputQualityWeak;
  final earlyLabel = earlyRead ? t('earlyRead') : null;

  if (notUsefulReason == 'too_vague') {
    return UsefulResultTakeaway(
      type: UsefulResultTakeawayType.concrete,
      headline: t('result.concrete.headline'),
      whatItMeans: t('result.concrete.meaning'),
      whyUseful: t('result.concrete.why'),
      nextCheck: t('result.concreteNextCheck'),
      example: t('result.concrete.example'),
      confidenceLabel: earlyLabel,
    );
  }

  final hint = _normalizeHint(resultHint);
  var whyUseful = t('result.$hint.why');
  if (inputQualityWeak) whyUseful = '$whyUseful ${t('result.weakNudge')}';

  return UsefulResultTakeaway(
    type: _typeForHint(hint),
    headline: t('result.$hint.headline'),
    whatItMeans: t('result.$hint.meaning'),
    whyUseful: whyUseful,
    nextCheck: inputQualityWeak
        ? t('result.concreteNextCheck')
        : t('result.$hint.nextCheck'),
    example: t('result.$hint.example'),
    confidenceLabel: earlyLabel,
  );
}

UsefulResultTakeawayType _typeForHint(String hint) {
  switch (hint) {
    case 'lighter':
      return UsefulResultTakeawayType.lighter;
    case 'heavier':
      return UsefulResultTakeawayType.heavier;
    case 'changed':
      return UsefulResultTakeawayType.changed;
    case 'same':
    default:
      return UsefulResultTakeawayType.repeat;
  }
}

String _normalizeHint(String resultHint) {
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

UsefulResultTakeaway _baseForHint(String hint) {
  switch (hint) {
    case 'lighter':
      return const UsefulResultTakeaway(
        type: UsefulResultTakeawayType.lighter,
        headline: 'Something made this lighter.',
        whatItMeans: 'Today this pattern took less from you.',
        whyUseful: 'That is useful because it points to what helped.',
        nextCheck: 'What helped make it lighter?',
        example: 'It felt lighter after I paused.',
      );
    case 'heavier':
      return const UsefulResultTakeaway(
        type: UsefulResultTakeawayType.heavier,
        headline: 'Something made this heavier.',
        whatItMeans: 'Today this pattern took more from you.',
        whyUseful: 'That is useful because it shows what needs attention.',
        nextCheck: 'What made it heavier?',
        example: 'It got heavier after I carried it alone.',
      );
    case 'changed':
      return const UsefulResultTakeaway(
        type: UsefulResultTakeawayType.changed,
        headline: 'Today was different.',
        whatItMeans: 'This was not just the same pattern repeating.',
        whyUseful: 'That is useful because change shows what can move.',
        nextCheck: 'What was different today?',
        example: 'It changed when I waited before answering.',
      );
    case 'same':
    default:
      return const UsefulResultTakeaway(
        type: UsefulResultTakeawayType.repeat,
        headline: 'This was a repeat, not a one-off.',
        whatItMeans: 'The same pattern showed up again today.',
        whyUseful: 'Repeats are useful because they show where to look next.',
        nextCheck: 'What happened right before it showed up?',
        example: 'It started before I said yes.',
      );
  }
}
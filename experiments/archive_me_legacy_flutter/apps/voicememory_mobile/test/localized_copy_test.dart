import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';

void main() {
  test('returns English copy for en', () {
    expect(localized('useThisTomorrow', 'en'), 'Use this tomorrow');
    expect(localized('usefulTakeaway', 'en'), 'Useful takeaway');
  });

  test('returns translated copy for supported languages', () {
    expect(localized('useThisTomorrow', 'es'), 'Usar esto mañana');
    expect(localized('useThisTomorrow', 'fr'), isNot('Use this tomorrow'));
    expect(localized('useThisTomorrow', 'hi'), isNotEmpty);
    expect(localized('useThisTomorrow', 'gu'), isNotEmpty);
  });

  test('falls back to English for an unsupported language', () {
    expect(localized('usefulTakeaway', 'de'), 'Useful takeaway');
  });

  test('falls back to the key when it is missing everywhere', () {
    expect(localized('totally_missing_key', 'es'), 'totally_missing_key');
  });

  test('perspective labels exist in English and translate', () {
    expect(localized('anotherPerspective', 'en'), 'Another perspective');
    expect(
      localized('showAnotherPerspective', 'en'),
      'Show another perspective',
    );
    expect(localized('useThisCheck', 'en'), 'Use this check');
    expect(localized('showAnother', 'en'), 'Show another');

    expect(localized('anotherPerspective', 'es'), isNot('Another perspective'));
    expect(localized('useThisCheck', 'es'), isNot('Use this check'));
    expect(localized('anotherPerspective', 'fr'), isNotEmpty);
    expect(localized('anotherPerspective', 'hi'), isNotEmpty);
    expect(localized('anotherPerspective', 'gu'), isNotEmpty);
  });

  test('kinder angle labels exist in English and translate', () {
    expect(localized('aKinderAngle', 'en'), 'A kinder angle');
    expect(localized('whyThisHelps', 'en'), 'Why this helps');
    expect(localized('showAnotherAngle', 'en'), 'Show another angle');
    expect(
      localized('kinderCaution', 'en'),
      'Use what fits. Leave what does not.',
    );

    expect(localized('aKinderAngle', 'es'), isNot('A kinder angle'));
    expect(localized('aKinderAngle', 'fr'), isNotEmpty);
    expect(localized('aKinderAngle', 'hi'), isNotEmpty);
    expect(localized('aKinderAngle', 'gu'), isNotEmpty);
  });

  test('quick help labels exist in English and translate', () {
    expect(localized('needHelp', 'en'), 'Need help?');
    expect(localized('needHelpNow', 'en'), 'Need help now?');
    expect(
      localized('quickHelpSubtitle', 'en'),
      'Pick what you need. ArchiveMe will give one next step.',
    );
    expect(
      localized('quickHelpWhatToRecord', 'en'),
      'I do not know what to record',
    );
    expect(localized('backToOptions', 'en'), 'Back to options');

    expect(localized('needHelp', 'es'), isNot('Need help?'));
    expect(localized('quickHelpWhatToRecord', 'fr'), isNotEmpty);
    expect(localized('needHelpNow', 'hi'), isNotEmpty);
    expect(localized('backToOptions', 'gu'), isNotEmpty);
  });

  test('localized category title is null for English', () {
    expect(localizedCategoryTitle('responsibility', 'en'), isNull);
  });

  test('localized category title is provided for other languages', () {
    final es = localizedCategoryTitle('responsibility', 'es');
    expect(es, isNotNull);
    expect(es, isNotEmpty);
  });

  test('all six categories localize for every supported language', () {
    const categories = [
      'responsibility',
      'worry',
      'relationship',
      'selfDoubt',
      'avoidance',
      'burnout',
    ];
    for (final lang in ['es', 'fr', 'hi', 'gu']) {
      for (final cat in categories) {
        final title = localizedCategoryTitle(cat, lang);
        expect(title, isNotNull, reason: '$cat/$lang');
        expect(title, isNotEmpty, reason: '$cat/$lang');
        expect(title!.startsWith('category.'), isFalse, reason: '$cat/$lang');
      }
    }
  });

  test('localized result headline keeps English copy for en', () {
    expect(
      localizedResultHeadline('showed_up_again', 'en'),
      'It showed up again.',
    );
    expect(
      localizedResultHeadline('not_today', 'en'),
      'Something changed today.',
    );
    expect(
      localizedResultHeadline('none_fit', 'en'),
      'None of those fit today.',
    );
  });

  test('localized result headline translates for other languages', () {
    expect(
      localizedResultHeadline('lighter', 'es'),
      localized('feltLighter', 'es'),
    );
    expect(
      localizedResultHeadline('lighter', 'es'),
      isNot('It felt lighter today.'),
    );
    expect(localizedResultHeadline('showed_up_again', 'fr'), isNotEmpty);
    expect(localizedResultHeadline('heavier', 'hi'), isNotEmpty);
    expect(localizedResultHeadline('not_today', 'gu'), isNotEmpty);
  });

  test('localized check-in question keeps English templates for en', () {
    expect(
      localizedCheckInQuestion('lighter', 'en'),
      'What helped make it lighter?',
    );
    expect(localizedCheckInQuestion('heavier', 'en'), 'What made it heavier?');
  });

  test('localized check-in question translates for other languages', () {
    expect(
      localizedCheckInQuestion('lighter', 'es'),
      localized('result.lighter.nextCheck', 'es'),
    );
    expect(
      localizedCheckInQuestion('lighter', 'es'),
      isNot('What helped make it lighter?'),
    );
    expect(
      localizedCheckInQuestion('not_today', 'fr'),
      localized('result.changed.nextCheck', 'fr'),
    );
  });

  test('localized option label keeps the fallback for en', () {
    expect(
      localizedOptionLabel('lighter', 'It felt lighter', 'en'),
      'It felt lighter',
    );
  });

  test('localized option label translates for other languages', () {
    expect(
      localizedOptionLabel('lighter', 'It felt lighter', 'es'),
      localized('option.lighter', 'es'),
    );
    expect(
      localizedOptionLabel('showed_up_again', 'It showed up again', 'fr'),
      isNotEmpty,
    );
  });

  test('original-text toggle labels exist and translate', () {
    expect(localized('showOriginal', 'en'), 'Show original');
    expect(localized('hideOriginal', 'en'), 'Hide original');
    expect(localized('showOriginal', 'es'), isNot('Show original'));
    expect(localized('showOriginal', 'gu'), isNotEmpty);
  });
}

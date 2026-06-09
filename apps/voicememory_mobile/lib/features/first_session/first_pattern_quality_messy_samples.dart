import 'first_pattern_quality_sample.dart';
import 'first_pattern_quality_titles.dart';

/// Messy, realistic reflections for harder first-pattern QA.
abstract final class FirstPatternQualityMessySamples {
  FirstPatternQualityMessySamples._();

  static const int count = 62;

  static List<FirstPatternQualitySample> get all => [
        ...vague,
        ...multiTopic,
        ...negation,
        ...positiveNeutral,
        ...distinction,
        ...diaryLike,
      ];

  static final List<FirstPatternQualitySample> vague = [
    _v('vague-1', 'rough day', ['vague'], notes: 'Too little signal'),
    _v('vague-2', 'felt off', ['vague']),
    _v('vague-3', "I don't know", ['vague']),
    _v('vague-4', 'nothing much happened', ['vague', 'neutral']),
    _v('vague-5', 'same as usual', ['vague', 'neutral']),
    _v('vague-6', 'meh', ['vague']),
    _v('vague-7', 'idk kinda weird', ['vague']),
    _v('vague-8', 'just tired I guess', ['vague'], acceptableExtra: [FirstPatternQualityTitles.burnout]),
    _v('vague-9', 'long day', ['vague']),
    _v('vague-10', 'not sure what to say', ['vague']),
  ];

  static final List<FirstPatternQualitySample> multiTopic = [
    _m(
      'multi-1',
      'Exhausted and worried about my partner, kept replaying our argument',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.burnout,
        FirstPatternQualityTitles.relationship,
      ],
    ),
    _m(
      'multi-2',
      'Work pressure, guilty saying yes, and I put off the hard email',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.avoidance,
      ],
    ),
    _m(
      'multi-3',
      'Family tension and I feel I need to prove myself again at work',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.relationship,
        FirstPatternQualityTitles.selfDoubt,
      ],
    ),
    _m(
      'multi-4',
      'Burnt out but still saying yes to everyone, no energy left',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.burnout,
        FirstPatternQualityTitles.responsibility,
      ],
    ),
    _m(
      'multi-5',
      'Worried and procrastinating on the thing I keep avoiding',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.avoidance,
      ],
    ),
    _m(
      'multi-6',
      'Anxious, drained, and tense with my boss after that message',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.burnout,
        FirstPatternQualityTitles.relationship,
      ],
    ),
    _m(
      'multi-7',
      'Guilt, pressure, partner upset, cannot switch off tonight',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.relationship,
      ],
    ),
    _m(
      'multi-8',
      'Behind at work, stuck starting, feeling not good enough',
      ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.selfDoubt,
        FirstPatternQualityTitles.avoidance,
      ],
    ),
  ];

  static final List<FirstPatternQualitySample> negation = [
    _n(
      'neg-1',
      'I was not worried today, just a normal afternoon',
      unacceptable: [FirstPatternQualityTitles.worry],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _n(
      'neg-2',
      'I finally asked for help and it felt okay',
      unacceptable: [FirstPatternQualityTitles.responsibility],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.lighter,
      ],
    ),
    _n(
      'neg-3',
      'I did not feel guilty even when I said no',
      unacceptable: [FirstPatternQualityTitles.responsibility],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _n(
      'neg-4',
      'I stopped myself from overthinking and went for a walk',
      unacceptable: [FirstPatternQualityTitles.worry],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.lighter,
      ],
    ),
    _n(
      'neg-5',
      'No stress today, not anxious at all',
      unacceptable: [FirstPatternQualityTitles.worry],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _n(
      'neg-6',
      'Never felt responsible for their mood, I set a boundary',
      unacceptable: [FirstPatternQualityTitles.responsibility],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _n(
      'neg-7',
      'Without guilt I said no to the extra task',
      unacceptable: [FirstPatternQualityTitles.responsibility],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _n(
      'neg-8',
      'Less overwhelmed than yesterday, did not put it off',
      unacceptable: [FirstPatternQualityTitles.avoidance],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
  ];

  static final List<FirstPatternQualitySample> positiveNeutral = [
    _p('pos-1', 'Had coffee and walked outside', ['positive', 'neutral']),
    _p('pos-2', 'Felt calm after lunch, peaceful afternoon', ['positive', 'neutral']),
    _p('pos-3', 'Saw a friend and laughed, felt good', ['positive', 'neutral']),
    _p('pos-4', 'Proud I rested and enjoyed the evening', ['positive', 'neutral']),
    _p('pos-5', 'Relieved the call went okay', ['positive', 'neutral']),
    _p('pos-6', 'Okay day, nothing heavy', ['positive', 'neutral', 'vague']),
    _p('pos-7', 'Grateful for a quiet morning', ['positive', 'neutral']),
    _p('pos-8', 'Felt lighter after a walk', ['positive', 'neutral']),
  ];

  static final List<FirstPatternQualitySample> distinction = [
    _d(
      'dist-1',
      'I was tired',
      unacceptable: [FirstPatternQualityTitles.burnout],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
      notes: 'Single weak tired',
    ),
    _d(
      'dist-2',
      'I messaged my friend',
      unacceptable: [FirstPatternQualityTitles.relationship],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'dist-3',
      'I had work to do',
      unacceptable: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.burnout,
      ],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'dist-4',
      'My partner said hi',
      unacceptable: [FirstPatternQualityTitles.relationship],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'dist-5',
      'Feeling a bit tired after gym but okay',
      unacceptable: [FirstPatternQualityTitles.burnout],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.lighter,
      ],
    ),
    _d(
      'dist-6',
      'Sent a message to mum, nothing else',
      unacceptable: [FirstPatternQualityTitles.relationship],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'dist-7',
      'I was stuck in traffic',
      unacceptable: [FirstPatternQualityTitles.avoidance],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
      notes: 'stuck != procrastination',
    ),
    _d(
      'dist-8',
      'Exhausted after running a marathon, legs heavy',
      acceptable: [FirstPatternQualityTitles.burnout],
      unacceptable: [FirstPatternQualityTitles.worry],
    ),
  ];

  static final List<FirstPatternQualitySample> diaryLike = [
    _d(
      'diary-1',
      'umm rough day idk. work was alot. said yes to stuff again tho felt guilty?? might b nothing',
      tags: ['vague', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.responsibility,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
    ),
    _d(
      'diary-2',
      'cant sleep. same worry. partner text ignored. anxious + drained',
      tags: ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.relationship,
        FirstPatternQualityTitles.burnout,
      ],
    ),
    _d(
      'diary-3',
      'didnt do the thing. put it off. not good enough. compare myself to her',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.selfDoubt,
      ],
    ),
    _d(
      'diary-4',
      'coffee w friend laughed!! felt calm. no big story',
      tags: ['positive', 'neutral'],
      acceptable: [
        FirstPatternQualityTitles.lighter,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
    ),
    _d(
      'diary-5',
      'boss msg short. tension w colleague. saying yes too fast + pressure all week',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.relationship,
      ],
    ),
    _d(
      'diary-6',
      'finally asked for help. less guilt. still tired tho',
      tags: ['negation', 'multi'],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.lighter,
      ],
      unacceptable: [FirstPatternQualityTitles.responsibility],
    ),
    _d(
      'diary-7',
      'nothing much. same as usual. walked dog',
      tags: ['vague', 'neutral'],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'diary-8',
      'overwhelmed procrastinate stuck on project. fear failing. behind everyone',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.selfDoubt,
      ],
    ),
    _d(
      'diary-9',
      'not worried today!! peaceful. little tired only',
      tags: ['negation', 'positive'],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.lighter,
      ],
      unacceptable: [FirstPatternQualityTitles.worry],
    ),
    _d(
      'diary-10',
      'guilt pressure saying yes before help. family argument replaying. exhausted',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.relationship,
        FirstPatternQualityTitles.burnout,
      ],
    ),
    _d(
      'diary-11',
      'felt off. dont know. maybe worry maybe tired',
      tags: ['vague', 'ambiguous'],
      acceptable: [
        ...FirstPatternQualityTitles.fallbackTitles,
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.burnout,
      ],
    ),
    _d(
      'diary-12',
      'rough day at work but proud I left on time and felt lighter',
      tags: ['positive', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.lighter,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
    ),
    _d(
      'diary-13',
      'I was not guilty. I did ask. still tense with him though',
      tags: ['negation', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.relationship,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
      unacceptable: [FirstPatternQualityTitles.responsibility],
    ),
    _d(
      'diary-14',
      'couldnt start. delayed. overwhelmed. also anxious about tomorrow',
      tags: ['ambiguous', 'multi'],
      acceptable: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.worry,
      ],
    ),
    _d(
      'diary-15',
      'message friend. laughed. good evening no tension',
      tags: ['positive'],
      acceptable: [
        FirstPatternQualityTitles.lighter,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
      unacceptable: [FirstPatternQualityTitles.relationship],
    ),
    _d(
      'diary-16',
      'burnout drained no energy saying yes to more anyway guilt',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.burnout,
        FirstPatternQualityTitles.responsibility,
      ],
    ),
    _d(
      'diary-17',
      'stopped overthinking. relieved. slept better',
      tags: ['negation', 'positive'],
      acceptable: [
        FirstPatternQualityTitles.lighter,
        ...FirstPatternQualityTitles.fallbackTitles,
      ],
      unacceptable: [FirstPatternQualityTitles.worry],
    ),
    _d(
      'diary-18',
      'prove myself again. judged. put off call. stuck',
      tags: ['multi'],
      acceptable: [
        FirstPatternQualityTitles.selfDoubt,
        FirstPatternQualityTitles.avoidance,
      ],
    ),
    _d(
      'diary-19',
      'quiet morning coffee sunshine porch',
      tags: ['neutral', 'positive'],
      acceptable: FirstPatternQualityTitles.fallbackTitles,
    ),
    _d(
      'diary-20',
      'partner tension awkward ignored message replaying it',
      acceptable: [FirstPatternQualityTitles.relationship],
      unacceptable: [FirstPatternQualityTitles.worry],
    ),
  ];

  static FirstPatternQualitySample _v(
    String id,
    String text,
    List<String> tags, {
    String? notes,
    List<String>? acceptableExtra,
  }) =>
      FirstPatternQualitySample(
        id: id,
        reflectionText: text,
        expectedCategory: 'vague',
        acceptableTitles: [
          ...FirstPatternQualityTitles.fallbackTitles,
          if (acceptableExtra != null) ...acceptableExtra,
        ],
        unacceptableTitles: [
          FirstPatternQualityTitles.responsibility,
          FirstPatternQualityTitles.worry,
          FirstPatternQualityTitles.relationship,
          FirstPatternQualityTitles.selfDoubt,
          FirstPatternQualityTitles.avoidance,
        ],
        notes: notes,
        qaTags: tags,
      );

  static FirstPatternQualitySample _m(
    String id,
    String text,
    List<String> tags, {
    required List<String> acceptable,
    List<String>? unacceptable,
  }) =>
      FirstPatternQualitySample(
        id: id,
        reflectionText: text,
        expectedCategory: 'ambiguous',
        acceptableTitles: acceptable,
        unacceptableTitles: unacceptable ?? const [],
        qaTags: tags,
      );

  static FirstPatternQualitySample _n(
    String id,
    String text, {
    required List<String> unacceptable,
    required List<String> acceptable,
  }) =>
      FirstPatternQualitySample(
        id: id,
        reflectionText: text,
        expectedCategory: 'negation',
        acceptableTitles: acceptable,
        unacceptableTitles: unacceptable,
        qaTags: const ['negation'],
      );

  static FirstPatternQualitySample _p(
    String id,
    String text,
    List<String> tags,
  ) =>
      FirstPatternQualitySample(
        id: id,
        reflectionText: text,
        expectedCategory: 'positive',
        acceptableTitles: [
          FirstPatternQualityTitles.lighter,
          ...FirstPatternQualityTitles.fallbackTitles,
        ],
        unacceptableTitles: [
          FirstPatternQualityTitles.responsibility,
          FirstPatternQualityTitles.worry,
          FirstPatternQualityTitles.selfDoubt,
          FirstPatternQualityTitles.avoidance,
        ],
        qaTags: tags,
      );

  static FirstPatternQualitySample _d(
    String id,
    String text, {
    List<String> tags = const [],
    List<String>? acceptable,
    List<String>? unacceptable,
    String? notes,
  }) =>
      FirstPatternQualitySample(
        id: id,
        reflectionText: text,
        expectedCategory: 'distinction',
        acceptableTitles:
            acceptable ?? FirstPatternQualityTitles.fallbackTitles,
        unacceptableTitles: unacceptable ?? const [],
        notes: notes,
        qaTags: tags,
      );
}

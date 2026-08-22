import 'package:archiveme_mobile/features/first_session/first_pattern_quality_messy_samples.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_sample.dart';
import 'package:archiveme_mobile/features/first_session/first_pattern_quality_titles.dart';

/// Labeled reflections for internal first-pattern QA.
abstract class FirstPatternQualitySamples {
  FirstPatternQualitySamples._();

  static const int coreSampleCount = 36;
  static const int ambiguousSampleCount = 8;
  static const int messySampleCount = FirstPatternQualityMessySamples.count;

  /// Original curated set (cleaner).
  static List<FirstPatternQualitySample> get curated => [...core, ...ambiguous];

  /// Harder realistic set for regression QA.
  static List<FirstPatternQualitySample> get messy =>
      FirstPatternQualityMessySamples.all;

  static List<FirstPatternQualitySample> get hard => [...curated, ...messy];

  static List<FirstPatternQualitySample> get all => hard;

  static List<FirstPatternQualitySample> get core => [
    ...responsibility,
    ...worry,
    ...relationship,
    ...selfDoubt,
    ...avoidance,
    ...burnout,
  ];

  static List<FirstPatternQualitySample> get ambiguous => [
    const FirstPatternQualitySample(
      id: 'mix-worry-burnout-1',
      reflectionText:
          'I feel anxious and exhausted, worried, cannot switch off, drained with no energy',
      expectedCategory: 'mixed-worry-burnout',
      acceptableTitles: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.burnout,
      ],
      unacceptableTitles: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.relationship,
      ],
      notes: 'Close worry vs burnout scores — correction expected',
    ),
    const FirstPatternQualitySample(
      id: 'mix-worry-burnout-2',
      reflectionText:
          'So tired and stressed, the same worry keeps coming back and I feel drained',
      expectedCategory: 'mixed-worry-burnout',
      acceptableTitles: [
        FirstPatternQualityTitles.worry,
        FirstPatternQualityTitles.burnout,
      ],
      notes: 'Rumination plus energy collapse',
    ),
    const FirstPatternQualitySample(
      id: 'mix-resp-rel-1',
      reflectionText:
          'I said yes to my partner again and feel guilty about the tension between us',
      expectedCategory: 'mixed-responsibility-relationship',
      acceptableTitles: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.relationship,
      ],
      unacceptableTitles: [FirstPatternQualityTitles.fallback],
    ),
    const FirstPatternQualitySample(
      id: 'mix-resp-rel-2',
      reflectionText:
          'Family needed me and I feel responsible for the awkward argument with my mum',
      expectedCategory: 'mixed-responsibility-relationship',
      acceptableTitles: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.relationship,
      ],
    ),
    const FirstPatternQualitySample(
      id: 'mix-avoid-doubt-1',
      reflectionText:
          'I put off the presentation because I am not good enough and keep trying to prove myself',
      expectedCategory: 'mixed-avoidance-selfDoubt',
      acceptableTitles: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.selfDoubt,
      ],
      unacceptableTitles: [FirstPatternQualityTitles.fallback],
    ),
    const FirstPatternQualitySample(
      id: 'mix-avoid-doubt-2',
      reflectionText:
          'Stuck and delayed again, feeling like a failure and judged for falling behind',
      expectedCategory: 'mixed-avoidance-selfDoubt',
      acceptableTitles: [
        FirstPatternQualityTitles.avoidance,
        FirstPatternQualityTitles.selfDoubt,
      ],
    ),
    const FirstPatternQualitySample(
      id: 'neutral-1',
      reflectionText: 'A quiet afternoon with coffee and sunshine on the porch',
      expectedCategory: 'neutral',
      acceptableTitles: [FirstPatternQualityTitles.fallback],
      unacceptableTitles: [
        FirstPatternQualityTitles.responsibility,
        FirstPatternQualityTitles.worry,
      ],
      notes: 'Ordinary moment — fallback expected',
    ),
    const FirstPatternQualitySample(
      id: 'neutral-2',
      reflectionText:
          'Walked the dog, nice weather, nothing much to say about today',
      expectedCategory: 'neutral',
      acceptableTitles: [FirstPatternQualityTitles.fallback],
      notes: 'Low signal — fallback and low confidence',
    ),
  ];

  static List<FirstPatternQualitySample> get responsibility => [
    _core(
      id: 'resp-1',
      text:
          'I keep saying yes too fast and feel guilty about pressure before asking for help',
      category: 'responsibility',
    ),
    _core(
      id: 'resp-2',
      text:
          'Everyone needed me today and I feel responsible for carrying it alone',
      category: 'responsibility',
    ),
    _core(
      id: 'resp-3',
      text:
          'I should have asked sooner instead of saying yes and feeling guilty',
      category: 'responsibility',
    ),
    _core(
      id: 'resp-4',
      text:
          'I hate letting people down so I said yes again before checking what I need',
      category: 'responsibility',
    ),
    _core(
      id: 'resp-5',
      text:
          'There was pressure to help and I feel responsible even when I am exhausted',
      category: 'responsibility',
    ),
    _core(
      id: 'resp-6',
      text:
          'I said yes to cover for a colleague and now feel guilty I did not ask for help',
      category: 'responsibility',
    ),
  ];

  static List<FirstPatternQualitySample> get worry => [
    _core(
      id: 'worry-1',
      text: 'The same worry came back tonight and I could not switch off',
      category: 'worry',
    ),
    _core(
      id: 'worry-2',
      text:
          'I keep overthinking what I said and the fear will not leave me alone',
      category: 'worry',
    ),
    _core(
      id: 'worry-3',
      text: 'Anxious all day, stressed, replaying the conversation in my head',
      category: 'worry',
    ),
    _core(
      id: 'worry-4',
      text:
          'Worried about tomorrow and scared the same thought keeps coming back',
      category: 'worry',
    ),
    _core(
      id: 'worry-5',
      text:
          'I am thinking about it again instead of resting, hard to switch off',
      category: 'worry',
    ),
    _core(
      id: 'worry-6',
      text: 'My mind will not stop, same worry returning after I went to bed',
      category: 'worry',
    ),
  ];

  static List<FirstPatternQualitySample> get relationship => [
    _core(
      id: 'rel-1',
      text:
          'My partner and I had tension after an awkward message went ignored',
      category: 'relationship',
    ),
    _core(
      id: 'rel-2',
      text:
          'Argument with my mum left me upset and replaying what I should say',
      category: 'relationship',
    ),
    _core(
      id: 'rel-3',
      text:
          'My boss sent a short reply and I feel tension with my colleague now',
      category: 'relationship',
    ),
    _core(
      id: 'rel-4',
      text:
          'A friend felt disappointed in me and the relationship feels awkward',
      category: 'relationship',
    ),
    _core(
      id: 'rel-5',
      text:
          'Family dinner had tension and I keep thinking about my dad being upset',
      category: 'relationship',
    ),
    _core(
      id: 'rel-6',
      text:
          'There is unresolved tension with someone I care about after we argued',
      category: 'relationship',
    ),
  ];

  static List<FirstPatternQualitySample> get selfDoubt => [
    _core(
      id: 'doubt-1',
      text:
          'I am not good enough and keep trying to prove myself while feeling judged',
      category: 'selfDoubt',
    ),
    _core(
      id: 'doubt-2',
      text:
          'I failed again and feel behind compared with everyone else on the team',
      category: 'selfDoubt',
    ),
    _core(
      id: 'doubt-3',
      text: 'I doubt myself whenever I compare my progress and lose confidence',
      category: 'selfDoubt',
    ),
    _core(
      id: 'doubt-4',
      text: 'Trying to prove I am capable but worried I am not good enough',
      category: 'selfDoubt',
    ),
    _core(
      id: 'doubt-5',
      text:
          'Feeling judged after the review, like I am not enough no matter what I do',
      category: 'selfDoubt',
    ),
    _core(
      id: 'doubt-6',
      text:
          'I keep proving myself at work because I fear failure and comparison',
      category: 'selfDoubt',
    ),
  ];

  static List<FirstPatternQualitySample> get avoidance => [
    _core(
      id: 'avoid-1',
      text:
          'I put off the call again, cannot start, and feel stuck and overwhelmed',
      category: 'avoidance',
    ),
    _core(
      id: 'avoid-2',
      text:
          'Avoiding the email all day, procrastinating until later, hard to start',
      category: 'avoidance',
    ),
    _core(
      id: 'avoid-3',
      text: 'I delayed the task and froze, overwhelmed by how much is left',
      category: 'avoidance',
    ),
    _core(
      id: 'avoid-4',
      text: 'Put off what matters again, stuck before I even open the document',
      category: 'avoidance',
    ),
    _core(
      id: 'avoid-5',
      text: 'I said I would do it tomorrow but I am avoiding starting tonight',
      category: 'avoidance',
    ),
    _core(
      id: 'avoid-6',
      text:
          'Cannot start the project, overwhelmed, keeping busy with smaller tasks',
      category: 'avoidance',
    ),
  ];

  static List<FirstPatternQualitySample> get burnout => [
    _core(
      id: 'burnout-1',
      text: 'I am exhausted and drained with no energy, feeling heavy and flat',
      category: 'burnout',
    ),
    _core(
      id: 'burnout-2',
      text:
          'So tired I could sleep all day, burnt out and numb after this week',
      category: 'burnout',
    ),
    _core(
      id: 'burnout-3',
      text: 'No energy left, drained after too much, sleep did not help',
      category: 'burnout',
    ),
    _core(
      id: 'burnout-4',
      text: 'Feeling flat and heavy, exhausted before the day even started',
      category: 'burnout',
    ),
    _core(
      id: 'burnout-5',
      text:
          'Burnout is catching up, I am tired of being tired and running on empty',
      category: 'burnout',
    ),
    _core(
      id: 'burnout-6',
      text:
          'Completely drained, too much on my plate, no energy for anyone tonight',
      category: 'burnout',
    ),
  ];

  static FirstPatternQualitySample _core({
    required String id,
    required String text,
    required String category,
  }) {
    final title = switch (category) {
      'responsibility' => FirstPatternQualityTitles.responsibility,
      'worry' => FirstPatternQualityTitles.worry,
      'relationship' => FirstPatternQualityTitles.relationship,
      'selfDoubt' => FirstPatternQualityTitles.selfDoubt,
      'avoidance' => FirstPatternQualityTitles.avoidance,
      'burnout' => FirstPatternQualityTitles.burnout,
      _ => FirstPatternQualityTitles.fallback,
    };
    return FirstPatternQualitySample(
      id: id,
      reflectionText: text,
      expectedCategory: category,
      acceptableTitles: [title],
      unacceptableTitles: FirstPatternQualityTitles.unacceptableFor(category),
    );
  }
}
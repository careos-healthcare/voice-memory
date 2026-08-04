/// Explicit comparison dimensions for the V1 semantic trust path.
///
/// Two saved moments are never compared as raw strings. Each moment is reduced
/// to the dimensions its own words actually support, and only dimensions
/// observed in both moments may be compared. A dimension that neither moment
/// mentions is absent rather than assumed equal.
library;

enum ChangeDimension {
  situation,
  action,
  behaviouralResponse,
  emotionalState,
  emotionalIntensity,
  certainty,
  frequency,
  duration,
  stoppingOrCompletionBehaviour,
  copingResponse,
  outcome,
}

extension ChangeDimensionLabel on ChangeDimension {
  /// Reader-facing label. Plain description of what was compared — never a
  /// clinical or trait term.
  String get label => switch (this) {
    ChangeDimension.situation => 'the situation',
    ChangeDimension.action => 'what you did',
    ChangeDimension.behaviouralResponse => 'how you responded',
    ChangeDimension.emotionalState => 'how you felt',
    ChangeDimension.emotionalIntensity => 'how strongly you felt it',
    ChangeDimension.certainty => 'how certain you sounded',
    ChangeDimension.frequency => 'how often it happened',
    ChangeDimension.duration => 'how long it lasted',
    ChangeDimension.stoppingOrCompletionBehaviour => 'stopping or finishing',
    ChangeDimension.copingResponse => 'how you handled it',
    ChangeDimension.outcome => 'how it turned out',
  };
}

enum DimensionDirection { increased, decreased, replaced, unchanged }

extension DimensionDirectionLabel on DimensionDirection {
  String get label => switch (this) {
    DimensionDirection.increased => 'more',
    DimensionDirection.decreased => 'less',
    DimensionDirection.replaced => 'different',
    DimensionDirection.unchanged => 'the same',
  };
}

/// What one saved moment says about one dimension, and nothing more.
class DimensionObservation {
  const DimensionObservation({
    required this.dimension,
    required this.markers,
    this.ordinal,
  });

  final ChangeDimension dimension;

  /// The exact lowercase words from the moment that produced this reading.
  final Set<String> markers;

  /// Position on the dimension's ordered scale, when the dimension is graded.
  /// Null for dimensions that are categorical rather than graded.
  final int? ordinal;

  bool get isGraded => ordinal != null;
}

/// One dimension observed in both moments, with the movement between them.
class DimensionMovement {
  const DimensionMovement({
    required this.dimension,
    required this.before,
    required this.after,
    required this.direction,
  });

  final ChangeDimension dimension;
  final DimensionObservation before;
  final DimensionObservation after;
  final DimensionDirection direction;

  bool get isChange => direction != DimensionDirection.unchanged;

  /// Short evidence-bound description, e.g. "how certain you sounded: more".
  String get summary => '${dimension.label}: ${direction.label}';
}

/// Structured result of comparing two saved moments dimension by dimension.
class ChangeDimensions {
  const ChangeDimensions({
    required this.sharedSubjectMarkers,
    required this.movements,
  });

  const ChangeDimensions.empty()
    : sharedSubjectMarkers = const {},
      movements = const [];

  /// Content words present in both moments — the subject they share.
  final Set<String> sharedSubjectMarkers;

  /// Every dimension observed in both moments. Dimensions observed in only one
  /// moment are excluded: a missing mention is not evidence of sameness.
  final List<DimensionMovement> movements;

  List<DimensionMovement> get changed =>
      movements.where((movement) => movement.isChange).toList(growable: false);

  List<DimensionMovement> get consistent => movements
      .where((movement) => !movement.isChange)
      .toList(growable: false);

  bool get hasComparableDimension => movements.isNotEmpty;

  /// A defensible change needs at least one dimension that both moments speak
  /// to and that actually moved.
  bool get supportsChange => changed.isNotEmpty;

  /// A defensible repeat needs comparable dimensions that all held steady.
  bool get supportsRepeat => movements.isNotEmpty && changed.isEmpty;

  /// Evidence pointing both ways on the same reading.
  bool get isConflicting {
    final increased = changed
        .where((movement) => movement.direction == DimensionDirection.increased)
        .isNotEmpty;
    final decreased = changed
        .where((movement) => movement.direction == DimensionDirection.decreased)
        .isNotEmpty;
    return increased && decreased;
  }
}

/// Deterministic, on-device dimension reader.
///
/// It runs entirely on the user's saved words. It never infers a dimension the
/// moment did not state, and it never calls a model.
abstract final class ChangeDimensionReader {
  static const minimumSubjectMarkerLength = 4;

  static ChangeDimensions compare({
    required String before,
    required String after,
  }) {
    final beforeDimensions = read(before);
    final afterDimensions = read(after);
    final movements = <DimensionMovement>[];
    for (final dimension in ChangeDimension.values) {
      final earlier = beforeDimensions[dimension];
      final later = afterDimensions[dimension];
      if (earlier == null || later == null) continue;
      movements.add(
        DimensionMovement(
          dimension: dimension,
          before: earlier,
          after: later,
          direction: _direction(earlier, later),
        ),
      );
    }
    return ChangeDimensions(
      sharedSubjectMarkers: subjectMarkers(
        before,
      ).intersection(subjectMarkers(after)),
      movements: List.unmodifiable(movements),
    );
  }

  /// Every dimension the text supports, keyed by dimension.
  static Map<ChangeDimension, DimensionObservation> read(String text) {
    final tokens = _tokens(text);
    final phrases = _normalizedPhrase(text);
    final observations = <ChangeDimension, DimensionObservation>{};
    for (final entry in _lexicon.entries) {
      final dimension = entry.key;
      final scale = entry.value;
      final markers = <String>{};
      var ordinal = -1;
      for (final band in scale.readableBands) {
        for (final marker in band.markers) {
          final matched = marker.contains(' ')
              ? phrases.contains(' $marker ')
              : tokens.contains(marker);
          if (!matched) continue;
          markers.add(marker);
          final effective = scale.isGraded && _isDiminished(phrases, marker)
              ? 0
              : band.ordinal;
          if (effective > ordinal) ordinal = effective;
        }
      }
      if (markers.isEmpty) continue;
      observations[dimension] = DimensionObservation(
        dimension: dimension,
        markers: Set.unmodifiable(markers),
        ordinal: scale.isGraded ? ordinal : null,
      );
    }
    if (!observations.containsKey(ChangeDimension.situation)) {
      final subject = subjectMarkers(text);
      if (subject.isNotEmpty) {
        observations[ChangeDimension.situation] = DimensionObservation(
          dimension: ChangeDimension.situation,
          markers: Set.unmodifiable(subject),
        );
      }
    }
    return Map.unmodifiable(observations);
  }

  /// Content words that identify what a moment is about.
  static Set<String> subjectMarkers(String text) => _tokens(text)
      .where(
        (token) =>
            token.length >= minimumSubjectMarkerLength &&
            !_subjectStopWords.contains(token),
      )
      .map(_stem)
      .toSet();

  static DimensionDirection _direction(
    DimensionObservation before,
    DimensionObservation after,
  ) {
    final earlier = before.ordinal;
    final later = after.ordinal;
    if (earlier != null && later != null && earlier != later) {
      return later > earlier
          ? DimensionDirection.increased
          : DimensionDirection.decreased;
    }
    if (before.markers.intersection(after.markers).isNotEmpty) {
      return DimensionDirection.unchanged;
    }
    return earlier != null && later != null && earlier == later
        ? DimensionDirection.unchanged
        : DimensionDirection.replaced;
  }

  /// True when every occurrence of [marker] is negated or played down, so a
  /// graded marker such as "certain" in "less certain" cannot be read as the
  /// strong end of its scale.
  static bool _isDiminished(String phrase, String marker) {
    final pattern = RegExp(
      "(?:^| )([a-z0-9']+ )?${RegExp.escape(marker)}(?= |\$)",
    );
    var diminished = false;
    for (final match in pattern.allMatches(phrase)) {
      final prior = match.group(1)?.trim();
      if (prior == null || !_diminishers.contains(prior)) return false;
      diminished = true;
    }
    return diminished;
  }

  static const _diminishers = {
    'barely',
    'hardly',
    'less',
    'never',
    'no',
    'not',
    "aren't",
    "didn't",
    "don't",
    "isn't",
    "wasn't",
    "weren't",
  };

  static final RegExp _word = RegExp(r"[a-z0-9']+");

  static Set<String> _tokens(String value) => _word
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .toSet();

  static String _normalizedPhrase(String value) =>
      ' ${value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']+"), ' ').trim()} ';

  static String _stem(String token) => switch (token) {
    'answered' ||
    'answering' ||
    'responded' ||
    'responding' ||
    'response' => 'answer',
    'paused' || 'pausing' || 'pause' => 'pause',
    'planned' || 'planning' || 'plans' => 'plan',
    'meetings' => 'meeting',
    'messages' => 'message',
    'deadlines' => 'deadline',
    'replied' || 'replying' || 'replies' => 'reply',
    'checked' || 'checking' => 'check',
    'finished' || 'finishing' => 'finish',
    'stopped' || 'stopping' => 'stop',
    'started' || 'starting' => 'start',
    _ => token,
  };

  static const _subjectStopWords = {
    'about',
    'after',
    'again',
    'archive',
    'archiveme',
    'because',
    'been',
    'before',
    'being',
    'could',
    'didn',
    'does',
    'doing',
    'done',
    'each',
    'even',
    'ever',
    'every',
    'felt',
    'from',
    'have',
    'here',
    'into',
    'just',
    'like',
    'moment',
    'much',
    'must',
    'only',
    'other',
    'over',
    'possible',
    'really',
    'said',
    'same',
    'some',
    'still',
    'such',
    'than',
    'that',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'thing',
    'this',
    'those',
    'through',
    'time',
    'today',
    'very',
    'want',
    'well',
    'went',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'with',
    'would',
    'your',
  };

  static const _lexicon = <ChangeDimension, _DimensionScale>{
    ChangeDimension.emotionalState: _DimensionScale.categorical([
      'worried',
      'anxious',
      'stressed',
      'frustrated',
      'angry',
      'upset',
      'sad',
      'tired',
      'afraid',
      'scared',
      'ashamed',
      'guilty',
      'lonely',
      'calm',
      'relieved',
      'relaxed',
      'happy',
      'grateful',
      'content',
      'settled',
      'hopeful',
      'proud',
    ]),
    ChangeDimension.emotionalIntensity: _DimensionScale.graded([
      _DimensionBand(0, {
        'slightly',
        'a bit',
        'a little',
        'mildly',
        'barely',
        'less',
        'weaker',
        'lower',
      }),
      _DimensionBand(1, {'quite', 'fairly', 'somewhat', 'pretty'}),
      _DimensionBand(2, {
        'very',
        'really',
        'deeply',
        'strongly',
        'more',
        'stronger',
        'higher',
      }),
      _DimensionBand(3, {
        'overwhelmed',
        'overwhelming',
        'unbearable',
        'panicked',
        'extremely',
        'completely',
      }),
    ]),
    ChangeDimension.certainty: _DimensionScale.graded([
      _DimensionBand(0, {
        'unsure',
        'uncertain',
        'maybe',
        'perhaps',
        'might',
        'guess',
        'unclear',
        'doubt',
      }),
      _DimensionBand(1, {'probably', 'likely', 'think', 'seems', 'suppose'}),
      _DimensionBand(2, {
        'certain',
        'sure',
        'definitely',
        'clearly',
        'know',
        'convinced',
      }),
    ]),
    ChangeDimension.frequency: _DimensionScale.graded([
      _DimensionBand(0, {'never', 'rarely', 'once', 'seldom'}),
      _DimensionBand(1, {'sometimes', 'occasionally'}),
      _DimensionBand(2, {'often', 'frequently', 'repeatedly', 'regularly'}),
      _DimensionBand(3, {'always', 'constantly', 'every time', 'each time'}),
    ]),
    ChangeDimension.duration: _DimensionScale.graded([
      _DimensionBand(0, {
        'immediately',
        'instantly',
        'briefly',
        'quickly',
        'straight away',
        'right away',
      }),
      _DimensionBand(1, {'minutes', 'a while', 'shorter', 'short'}),
      _DimensionBand(2, {
        'hours',
        'all day',
        'longer',
        'lingered',
        'days',
        'weeks',
      }),
    ]),
    ChangeDimension.action: _DimensionScale.categorical([
      'answered',
      'answering',
      'replied',
      'replying',
      'asked',
      'called',
      'messaged',
      'emailed',
      'wrote',
      'said',
      'told',
      'sent',
      'went',
      'left',
      'stayed',
      'waited',
      'checked',
      'read',
      'planned',
      'booked',
      'cancelled',
    ]),
    ChangeDimension.behaviouralResponse: _DimensionScale.categorical([
      'paused',
      'hesitated',
      'reacted',
      'snapped',
      'withdrew',
      'avoided',
      'confronted',
      'ignored',
      'engaged',
      'listened',
      'apologised',
      'apologized',
      'explained',
      'pushed back',
      'agreed',
      'refused',
    ]),
    ChangeDimension.stoppingOrCompletionBehaviour: _DimensionScale.categorical([
      'stopped',
      'finished',
      'completed',
      'gave up',
      'quit',
      'kept going',
      'continued',
      'carried on',
      'abandoned',
      'wrapped up',
      'closed',
      'left it',
    ]),
    ChangeDimension.copingResponse: _DimensionScale.categorical([
      'walked',
      'breathed',
      'slept',
      'rested',
      'talked',
      'vented',
      'journaled',
      'exercised',
      'distracted',
      'drank',
      'scrolled',
      'ruminated',
      'prepared',
      'planned',
      'asked for help',
      'reached out',
    ]),
    ChangeDimension.outcome: _DimensionScale.categorical([
      'worked',
      'helped',
      'failed',
      'backfired',
      'resolved',
      'unresolved',
      'better',
      'worse',
      'fine',
      'easier',
      'harder',
      'no difference',
    ]),
  };
}

class _DimensionBand {
  const _DimensionBand(this.ordinal, this.markers);

  final int ordinal;
  final Set<String> markers;
}

class _DimensionScale {
  const _DimensionScale.graded(this.bands) : isGraded = true, _flat = null;

  const _DimensionScale.categorical(List<String> markers)
    : bands = const [],
      isGraded = false,
      _flat = markers;

  final List<_DimensionBand> bands;
  final bool isGraded;
  final List<String>? _flat;

  Iterable<_DimensionBand> get readableBands {
    final flat = _flat;
    return flat == null ? bands : [_DimensionBand(0, flat.toSet())];
  }
}

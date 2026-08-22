import 'package:archiveme_mobile/features/input_quality/input_quality_engine.dart';
import 'package:archiveme_mobile/features/perspective/perspective_shift_model.dart';

const String _earlyReadLabel = 'Early read';

/// Builds one grounded perspective on a reflection/result.
///
/// Stays grounded: it only reframes what the user said via [reflectionText],
/// [checkInQuestion], and [patternTitle]. It never invents facts or gives
/// advice. [preferredType] forces a specific angle (used by the "Show another
/// perspective" cycle); otherwise the angle is chosen from [resultHint].
PerspectiveShift buildPerspectiveShift({
  required String reflectionText,
  String? resultHint,
  String? checkInQuestion,
  String? patternTitle,
  PerspectiveShiftType? preferredType,
}) {
  final type = preferredType ?? preferredPerspectiveType(resultHint);
  final weak = _isWeak(reflectionText);
  final base = _baseFor(type);
  final source = _sourcePhrase(reflectionText, patternTitle);

  if (weak) {
    return PerspectiveShift(
      type: type,
      title: base.title,
      perspective:
          'This is an early read. Add one clearer moment to make the '
          'perspective sharper.',
      whyUseful: base.whyUseful,
      nextCheck: 'What exact moment did this show up?',
      confidenceLabel: _earlyReadLabel,
      sourcePhrase: source,
    );
  }

  return PerspectiveShift(
    type: type,
    title: base.title,
    perspective: base.perspective,
    whyUseful: base.whyUseful,
    nextCheck: base.nextCheck,
    sourcePhrase: source,
  );
}

/// The default angle for a result hint. Used to seed the perspective cycle.
PerspectiveShiftType preferredPerspectiveType(String? resultHint) {
  switch (_normalizeHint(resultHint)) {
    case 'lighter':
      return PerspectiveShiftType.kindness;
    case 'heavier':
      return PerspectiveShiftType.pressure;
    case 'changed':
      return PerspectiveShiftType.nextStep;
    case 'same':
      return PerspectiveShiftType.pattern;
    default:
      return PerspectiveShiftType.pattern;
  }
}

/// The full cycle of angles for "Show another perspective", seeded so the
/// preferred angle for [resultHint] comes first.
List<PerspectiveShiftType> perspectiveCycle(String? resultHint) {
  final first = preferredPerspectiveType(resultHint);
  return [
    first,
    for (final t in PerspectiveShiftType.values)
      if (t != first) t,
  ];
}

String _normalizeHint(String? resultHint) {
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

/// A null/empty reflection is "not provided" and is not treated as weak (the
/// perspective is grounded in the result/pattern instead). A short or vague
/// reflection is weak and earns an "Early read".
bool _isWeak(String reflectionText) {
  final trimmed = reflectionText.trim();
  if (trimmed.isEmpty) return false;
  return assessReflectionQuality(trimmed).shouldAskForSharpening;
}

String? _sourcePhrase(String reflectionText, String? patternTitle) {
  final trimmed = reflectionText.trim();
  if (trimmed.isNotEmpty) {
    final words = trimmed.split(RegExp(r'\s+'));
    final snippet = words.take(10).join(' ');
    return words.length > 10 ? '$snippet…' : snippet;
  }
  final title = patternTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  return null;
}

_PerspectiveBase _baseFor(PerspectiveShiftType type) {
  switch (type) {
    case PerspectiveShiftType.pattern:
      return const _PerspectiveBase(
        title: 'One pattern to notice',
        perspective:
            'This may not be about the whole day. It may be about the '
            'moment before it starts.',
        whyUseful: 'That gives you a smaller place to look next.',
        nextCheck: 'What happens right before this shows up?',
      );
    case PerspectiveShiftType.pressure:
      return const _PerspectiveBase(
        title: 'Where pressure enters',
        perspective:
            'This sounds like pressure arrived before you had time to choose.',
        whyUseful:
            'That matters because pressure often makes the next step feel '
            'automatic.',
        nextCheck: 'Where did the pressure first show up?',
      );
    case PerspectiveShiftType.need:
      return const _PerspectiveBase(
        title: 'What you may have needed',
        perspective:
            'Another way to see this is that something needed attention '
            'before you pushed through.',
        whyUseful: 'Naming the need can make tomorrow\u2019s check clearer.',
        nextCheck: 'What did you need before this got heavier?',
      );
    case PerspectiveShiftType.choice:
      return const _PerspectiveBase(
        title: 'Where there may be a choice point',
        perspective:
            'The useful part may be the small moment before you answered, '
            'delayed, carried it, or kept going.',
        whyUseful: 'That is where the pattern may be easier to notice.',
        nextCheck: 'Where was the choice point?',
      );
    case PerspectiveShiftType.kindness:
      return const _PerspectiveBase(
        title: 'A kinder angle',
        perspective:
            'This may make more sense if you see it as a hard moment, not a '
            'personal failure.',
        whyUseful: 'That can make it easier to record honestly tomorrow.',
        nextCheck: 'What would you say if this happened to someone else?',
      );
    case PerspectiveShiftType.nextStep:
      return const _PerspectiveBase(
        title: 'One next step',
        perspective:
            'The next useful move is not to solve the whole pattern. It is '
            'to catch one moment earlier.',
        whyUseful: 'One clear moment is easier to compare tomorrow.',
        nextCheck: 'What is one moment you can catch earlier?',
      );
  }
}

class _PerspectiveBase {
  const _PerspectiveBase({
    required this.title,
    required this.perspective,
    required this.whyUseful,
    required this.nextCheck,
  });

  final String title;
  final String perspective;
  final String whyUseful;
  final String nextCheck;
}
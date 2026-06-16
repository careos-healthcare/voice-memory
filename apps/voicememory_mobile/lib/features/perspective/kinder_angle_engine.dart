import '../input_quality/input_quality_engine.dart';
import 'kinder_angle_model.dart';

const String _earlyReadLabel = 'Early read';
const String _cautionLine = 'Use what fits. Leave what does not.';

/// Builds a grounded "kinder angle" on a hard moment.
///
/// Stays grounded in what the user said: it reframes the moment, never invents
/// facts, never diagnoses, never says "you should", and never uses generic
/// comfort copy. The angle always lands on a concrete [nextCheck] so it feeds
/// the pattern/check loop instead of replacing it.
///
/// [triggerOverride] forces a specific angle (used by the Patterns surface and
/// "Show another angle"); otherwise the trigger is detected from the text.
KinderAngle buildKinderAngle({
  required String reflectionText,
  String? patternTitle,
  String? resultHint,
  String? languageCode,
  KinderAngleTrigger? triggerOverride,
}) {
  final trimmed = reflectionText.trim();
  final trigger =
      triggerOverride ??
      detectKinderAngleTrigger(trimmed) ??
      KinderAngleTrigger.genericHardMoment;
  final source = _sourcePhrase(trimmed, patternTitle);
  final base = _baseFor(trigger);

  final weak = triggerOverride == null && _isWeak(trimmed);
  if (weak) {
    return KinderAngle(
      trigger: trigger,
      title: base.title,
      kinderRead:
          'This is an early read. Add one clearer moment to make this more '
          'useful.',
      whyThisHelps: base.whyThisHelps,
      nextCheck: 'What exact moment felt hard?',
      cautionLine: _cautionLine,
      confidenceLabel: _earlyReadLabel,
      sourcePhrase: source,
    );
  }

  return KinderAngle(
    trigger: trigger,
    title: base.title,
    kinderRead: base.kinderRead,
    whyThisHelps: base.whyThisHelps,
    nextCheck: base.nextCheck,
    cautionLine: _cautionLine,
    sourcePhrase: source,
  );
}

/// Whether a kinder angle is worth showing for this reflection/result.
///
/// Returns false for neutral input (no hard-moment signal), and for a clearly
/// lighter result unless the user is being hard on themselves (self-blame).
bool shouldShowKinderAngle(String reflectionText, {String? resultHint}) {
  final trigger = detectKinderAngleTrigger(reflectionText.trim());
  if (trigger == null) return false;
  if (_normalizeHint(resultHint) == 'lighter' &&
      trigger != KinderAngleTrigger.selfBlame) {
    return false;
  }
  return true;
}

/// The detected trigger, or null when the input is neutral (no hard moment).
KinderAngleTrigger? detectKinderAngleTrigger(String text) {
  final lower = text.toLowerCase();
  if (lower.trim().isEmpty) return null;

  if (_containsAny(lower, _selfBlameWords)) {
    return KinderAngleTrigger.selfBlame;
  }
  if (_containsAny(lower, _pressureWords)) {
    return KinderAngleTrigger.pressure;
  }
  if (_containsAny(lower, _tirednessWords)) {
    return KinderAngleTrigger.tiredness;
  }
  if (_containsAny(lower, _avoidanceWords)) {
    return KinderAngleTrigger.avoidance;
  }
  if (_containsAny(lower, _relationshipWords)) {
    return KinderAngleTrigger.relationship;
  }
  if (_containsAny(lower, _genericHardWords)) {
    return KinderAngleTrigger.genericHardMoment;
  }
  return null;
}

const List<String> _selfBlameWords = [
  'stupid',
  'failure',
  'useless',
  'not good enough',
  'my fault',
  'pathetic',
  'lazy',
  'weak',
  'embarrassed',
  'ashamed',
];

const List<String> _pressureWords = [
  'pressure',
  'guilt',
  'said yes',
  'responsibility',
  'carry',
  'carried',
  'expected',
  'should',
  'had to',
];

const List<String> _tirednessWords = [
  'tired',
  'exhausted',
  'drained',
  'no energy',
  'burned out',
  'flat',
  'heavy',
];

const List<String> _avoidanceWords = [
  'avoided',
  'delayed',
  'put off',
  'procrastinated',
  'could not start',
  'ignored',
  'left it',
];

const List<String> _relationshipWords = [
  'conversation',
  'message',
  'partner',
  'friend',
  'mum',
  'dad',
  'colleague',
  'boss',
  'replayed',
  'tension',
  'awkward',
];

/// Broader "this was hard" signal used for the generic fallback only.
const List<String> _genericHardWords = [
  'hard',
  'difficult',
  'struggled',
  'struggling',
  'worse',
  'upset',
  'anxious',
  'worried',
  'worry',
  'sad',
  'angry',
  'frustrated',
  'cried',
  'overwhelmed',
  'stressed',
  'stressful',
  'bad day',
];

bool _containsAny(String lower, List<String> words) {
  for (final w in words) {
    if (lower.contains(w)) return true;
  }
  return false;
}

String _normalizeHint(String? resultHint) {
  switch (resultHint) {
    case 'lighter':
      return 'lighter';
    case 'heavier':
      return 'heavier';
    case 'same':
    case 'showed_up_again':
      return 'same';
    case 'changed':
    case 'not_today':
    case 'none_fit':
      return 'changed';
    default:
      return '';
  }
}

bool _isWeak(String reflectionText) {
  if (reflectionText.isEmpty) return true;
  return assessReflectionQuality(reflectionText).shouldAskForSharpening;
}

String? _sourcePhrase(String reflectionText, String? patternTitle) {
  if (reflectionText.isNotEmpty) {
    final words = reflectionText.split(RegExp(r'\s+'));
    final snippet = words.take(10).join(' ');
    return words.length > 10 ? '$snippet…' : snippet;
  }
  final title = patternTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  return null;
}

_KinderBase _baseFor(KinderAngleTrigger trigger) {
  switch (trigger) {
    case KinderAngleTrigger.selfBlame:
      return const _KinderBase(
        kinderRead:
            'This may be a hard moment, not proof that something is wrong '
            'with you.',
        whyThisHelps:
            'That makes it easier to look at what happened without turning it '
            'into a judgment.',
        nextCheck: 'What happened right before you judged yourself?',
      );
    case KinderAngleTrigger.pressure:
      return const _KinderBase(
        kinderRead:
            'This may be about pressure arriving before you had time to '
            'choose.',
        whyThisHelps: 'That gives you a smaller moment to notice next time.',
        nextCheck: 'Where did the pressure first show up?',
      );
    case KinderAngleTrigger.tiredness:
      return const _KinderBase(
        kinderRead: 'This may be about running low, not failing.',
        whyThisHelps: 'That helps separate the moment from your whole self.',
        nextCheck: 'What changed when your energy was low?',
      );
    case KinderAngleTrigger.avoidance:
      return const _KinderBase(
        kinderRead:
            'This may be avoidance protecting you from pressure for a while.',
        whyThisHelps:
            'That makes the pattern easier to notice without blaming yourself.',
        nextCheck: 'What pressure showed up before you delayed it?',
      );
    case KinderAngleTrigger.relationship:
      return const _KinderBase(
        kinderRead:
            'This may be about a moment that stayed with you, not just the '
            'other person.',
        whyThisHelps: 'That helps you check what you carried afterward.',
        nextCheck: 'What stayed with you after the conversation?',
      );
    case KinderAngleTrigger.genericHardMoment:
      return const _KinderBase(
        kinderRead: 'This may be one hard moment, not the whole story.',
        whyThisHelps: 'That makes it easier to record honestly tomorrow.',
        nextCheck: 'What was the hardest moment today?',
      );
  }
}

class _KinderBase {
  const _KinderBase({
    required this.kinderRead,
    required this.whyThisHelps,
    required this.nextCheck,
  });

  final String kinderRead;
  final String whyThisHelps;
  final String nextCheck;

  String get title => 'A kinder angle';
}

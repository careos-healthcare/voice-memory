/// What in the reflection invited a kinder reading of a hard moment.
enum KinderAngleTrigger {
  selfBlame,
  pressure,
  tiredness,
  avoidance,
  relationship,
  genericHardMoment,
}

extension KinderAngleTriggerIds on KinderAngleTrigger {
  String get id => name;
}

/// A grounded, kinder way to read the same hard moment.
///
/// Everything is built from what the user said — no comfort scripts, no advice,
/// no diagnosis. [cautionLine] keeps it optional ("use what fits"); the angle
/// always lands on a concrete [nextCheck] so it supports the pattern loop.
class KinderAngle {
  const KinderAngle({
    required this.trigger,
    required this.title,
    required this.kinderRead,
    required this.whyThisHelps,
    required this.nextCheck,
    required this.cautionLine,
    this.confidenceLabel,
    this.sourcePhrase,
  });

  final KinderAngleTrigger trigger;
  final String title;
  final String kinderRead;
  final String whyThisHelps;
  final String nextCheck;
  final String cautionLine;

  /// "Early read" when the reflection was thin/vague; otherwise null.
  final String? confidenceLabel;

  /// A short grounding snippet drawn from the reflection/pattern, or null.
  final String? sourcePhrase;

  bool get isEarlyRead => confidenceLabel != null;
}
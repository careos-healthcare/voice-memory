/// A useful angle on a moment the user just recorded.
enum PerspectiveShiftType {
  pattern,
  pressure,
  need,
  choice,
  kindness,
  nextStep,
}

extension PerspectiveShiftTypeIds on PerspectiveShiftType {
  String get id => name;
}

/// One grounded perspective on a reflection/result, plus a next check.
///
/// Everything here is built from what the user said — no invented facts, no
/// advice. [sourcePhrase] keeps a short, grounding snippet of the input.
class PerspectiveShift {
  const PerspectiveShift({
    required this.type,
    required this.title,
    required this.perspective,
    required this.whyUseful,
    required this.nextCheck,
    this.confidenceLabel,
    this.sourcePhrase,
  });

  final PerspectiveShiftType type;
  final String title;
  final String perspective;
  final String whyUseful;
  final String nextCheck;

  /// "Early read" when the reflection was thin/vague; otherwise null.
  final String? confidenceLabel;

  /// A short grounding snippet drawn from the reflection/pattern, or null.
  final String? sourcePhrase;

  bool get isEarlyRead => confidenceLabel != null;
}

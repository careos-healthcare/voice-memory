/// What the user is stuck on when they open Quick help.
enum QuickHelpIntent {
  whatToRecord,
  anotherPerspective,
  practicalNextStep,
  kinderAngle,
  whatToCheckNext,
}

extension QuickHelpIntentIds on QuickHelpIntent {
  String get id => name;
}

/// The kind of action the primary button performs for a response.
enum QuickHelpAction { startRecording, useThisCheck, showPerspective }

/// One short, practical answer for a [QuickHelpIntent].
///
/// Always one step — a title, a short body, and a single primary action. No
/// open-ended conversation, no long text.
class QuickHelpResponse {
  const QuickHelpResponse({
    required this.intent,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.action,
    this.secondaryLabel,
    this.nextCheck,
    this.example,
  });

  final QuickHelpIntent intent;
  final String title;
  final String body;
  final String actionLabel;
  final QuickHelpAction action;
  final String? secondaryLabel;
  final String? nextCheck;
  final String? example;
}

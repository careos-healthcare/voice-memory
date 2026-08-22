import 'package:archiveme_mobile/features/quick_help/quick_help_model.dart';

/// Builds one short, practical Quick help answer for the chosen [intent].
///
/// This is deliberately not a conversation: every intent maps to a single
/// grounded step inside the record/check loop. Bodies stay short and never give
/// advice, comfort scripts, or diagnosis.
QuickHelpResponse buildQuickHelpResponse({
  required QuickHelpIntent intent,
  String? latestReflectionText,
  String? patternTitle,
  String? resultHint,
  String? nextCheck,
}) {
  switch (intent) {
    case QuickHelpIntent.whatToRecord:
      return const QuickHelpResponse(
        intent: QuickHelpIntent.whatToRecord,
        title: 'Record one moment',
        body:
            'Do not explain the whole day. Say one moment that stayed with '
            'you.',
        actionLabel: 'Start recording',
        action: QuickHelpAction.startRecording,
        example: 'I said yes before checking what I needed.',
      );
    case QuickHelpIntent.anotherPerspective:
      return const QuickHelpResponse(
        intent: QuickHelpIntent.anotherPerspective,
        title: 'Try another perspective',
        body: 'Look at the smaller moment before the pattern started.',
        actionLabel: 'Show perspective',
        action: QuickHelpAction.showPerspective,
        nextCheck: 'What happened right before it showed up?',
      );
    case QuickHelpIntent.practicalNextStep:
      return const QuickHelpResponse(
        intent: QuickHelpIntent.practicalNextStep,
        title: 'One practical next step',
        body: 'Pick one thing to check tomorrow, not the whole pattern.',
        actionLabel: 'Use this check',
        action: QuickHelpAction.useThisCheck,
        nextCheck: 'What is one moment you can catch earlier?',
      );
    case QuickHelpIntent.kinderAngle:
      return const QuickHelpResponse(
        intent: QuickHelpIntent.kinderAngle,
        title: 'A kinder angle',
        body: 'This may be one hard moment, not the whole story.',
        actionLabel: 'Use this check',
        action: QuickHelpAction.useThisCheck,
        nextCheck: 'What was the hardest moment today?',
      );
    case QuickHelpIntent.whatToCheckNext:
      final existing = nextCheck?.trim();
      final resolved = (existing != null && existing.isNotEmpty)
          ? existing
          : 'What happens right before it starts?';
      return QuickHelpResponse(
        intent: QuickHelpIntent.whatToCheckNext,
        title: 'Your next check',
        body: (existing != null && existing.isNotEmpty)
            ? existing
            : 'Check what happens right before it starts.',
        actionLabel: 'Use this check',
        action: QuickHelpAction.useThisCheck,
        nextCheck: resolved,
      );
  }
}
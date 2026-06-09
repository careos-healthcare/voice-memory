/// A structured, consumer-facing reading of a completed check-in result.
///
/// Used when people return but say the result does not feel useful: it spells
/// out what changed, why that matters, and the next thing worth checking.
class CheckInResultInterpretation {
  const CheckInResultInterpretation({
    required this.headline,
    required this.whatChanged,
    required this.whyItMatters,
    required this.nextCheck,
    required this.oneSentenceSummary,
  });

  final String headline;
  final String whatChanged;
  final String whyItMatters;
  final String nextCheck;
  final String oneSentenceSummary;
}

/// Normalises a result hint to one of: same | lighter | heavier | changed.
///
/// Accepts both the short hints and the stored option ids so callers can pass
/// whichever they have.
String _normalizeResultHint(String resultHint) {
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

/// Extra guidance appended to "why it matters" for the top not-useful reason.
String? _reasonAddendum(String? topNotUsefulReason) {
  switch (topNotUsefulReason) {
    case 'too_vague':
      return 'Make it concrete: name the moment, not the whole day.';
    case 'not_accurate':
      return 'Choose the closest answer, then record one moment.';
    case 'already_knew_this':
      return 'The value is whether it changes tomorrow.';
    case 'confusing':
      return 'Use one sentence: what happened, and how it felt.';
    default:
      return null;
  }
}

/// Builds a [CheckInResultInterpretation] for a completed check-in.
CheckInResultInterpretation buildCheckInResultInterpretation({
  required String resultHint,
  required String question,
  required String? reflectionText,
  String? topNotUsefulReason,
}) {
  final hint = _normalizeResultHint(resultHint);

  late final String headline;
  late final String whatChanged;
  late final String whyItMatters;
  late final String nextCheck;

  switch (hint) {
    case 'lighter':
      headline = 'It felt lighter today.';
      whatChanged = 'Something made this easier today.';
      whyItMatters = 'That helps you see what may be working.';
      nextCheck = 'What helped make it lighter?';
    case 'heavier':
      headline = 'It felt heavier today.';
      whatChanged = 'This took more from you today.';
      whyItMatters = 'That is useful because it shows what needs attention.';
      nextCheck = 'What made it heavier?';
    case 'changed':
      headline = 'Something changed today.';
      whatChanged = 'Today was not just a repeat.';
      whyItMatters = 'Change is useful because it shows the pattern can move.';
      nextCheck = 'What was different today?';
    case 'same':
    default:
      headline = 'It showed up again.';
      whatChanged = 'This was a repeat, not a one-off.';
      whyItMatters =
          'Repeats are useful because they show where the pattern starts.';
      nextCheck = 'What happened right before it showed up?';
  }

  final addendum = _reasonAddendum(topNotUsefulReason);
  final why = addendum == null ? whyItMatters : '$whyItMatters $addendum';

  return CheckInResultInterpretation(
    headline: headline,
    whatChanged: whatChanged,
    whyItMatters: why,
    nextCheck: nextCheck,
    oneSentenceSummary: '$headline Next, check: $nextCheck',
  );
}

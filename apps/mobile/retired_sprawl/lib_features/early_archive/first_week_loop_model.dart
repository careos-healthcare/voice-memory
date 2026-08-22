/// Retention loop card after first proof — prompts the next related recording.
class FirstWeekLoop {
  const FirstWeekLoop({
    required this.title,
    required this.body,
    required this.label,
    required this.footer,
    required this.cta,
    required this.hasPhrase,
    required this.hasConfirmedRepeat,
    required this.usesPhraseBody,
  });

  final String title;
  final String body;
  final String label;
  final String footer;
  final String cta;
  final bool hasPhrase;
  final bool hasConfirmedRepeat;
  final bool usesPhraseBody;
}
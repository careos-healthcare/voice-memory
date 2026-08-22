class FirstRunPositioningResult {
  const FirstRunPositioningResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.footer,
    required this.entryCount,
    required this.source,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final String footer;
  final int entryCount;
  final String source;
}
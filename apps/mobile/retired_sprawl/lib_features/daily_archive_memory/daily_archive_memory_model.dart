/// Built daily archive memory card content — local evidence only.
class DailyThoughtprintmoryResult {
  const DailyThoughtprintmoryResult({
    required this.title,
    required this.body,
    required this.hasWatchTarget,
    required this.canShowPatternDetail,
    this.watchPhrase,
    this.footer,
  });

  final String title;
  final String body;
  final String? watchPhrase;
  final String? footer;
  final bool hasWatchTarget;
  final bool canShowPatternDetail;
}
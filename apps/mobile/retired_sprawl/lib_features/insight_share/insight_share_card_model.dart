/// Privacy-safe weekly reflection pattern share card — no raw journal text.
class InsightShareCardModel {
  const InsightShareCardModel({
    required this.id,
    required this.weekRangeLabel,
    required this.headline,
    required this.patternLines,
    required this.footer,
    required this.referralLink,
    required this.referralSource,
    required this.plainTextShare,
  });

  final String id;
  final String weekRangeLabel;
  final String headline;
  final List<String> patternLines;
  final String footer;
  final String referralLink;
  final String referralSource;
  final String plainTextShare;

  String get pngFilename => '$id.png';
}
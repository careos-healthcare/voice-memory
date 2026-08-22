import 'package:archiveme_mobile/features/share_card/share_card_copy.dart';

/// Privacy-safe share card content — no transcript, ids, or scores.
class ShareCardModel {
  const ShareCardModel({
    required this.patternKey,
    required this.displayPatternLabel,
    required this.relatedMomentCount,
    required this.hasChangeNoticed,
    required this.labelNeedsReview,
    required this.entryCount,
    required this.groundedPhrase,
  });

  final String patternKey;
  final String displayPatternLabel;
  final int relatedMomentCount;
  final bool hasChangeNoticed;
  final bool labelNeedsReview;
  final int entryCount;
  final String groundedPhrase;

  bool get canShare =>
      displayPatternLabel.trim().isNotEmpty && relatedMomentCount > 0;

  String get relatedMomentsLine =>
      ShareCardCopy.relatedMoments(relatedMomentCount);

  List<String> get imageLines => [
    ShareCardCopy.headline,
    displayPatternLabel.trim(),
    relatedMomentsLine,
    if (hasChangeNoticed) ShareCardCopy.changeNoticedLine,
    ShareCardCopy.footer,
  ];

  String get pngFilename =>
      'archiveme_share_card_${DateTime.now().millisecondsSinceEpoch}.png';

  ShareCardModel withDisplayLabel(String label) {
    return ShareCardModel(
      patternKey: patternKey,
      displayPatternLabel: label,
      relatedMomentCount: relatedMomentCount,
      hasChangeNoticed: hasChangeNoticed,
      labelNeedsReview: false,
      entryCount: entryCount,
      groundedPhrase: groundedPhrase,
    );
  }
}
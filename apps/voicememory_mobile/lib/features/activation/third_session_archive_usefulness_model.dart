/// Session-3 archive usefulness surface — conservative, evidence-based.
class ThirdSessionArchiveUsefulness {
  const ThirdSessionArchiveUsefulness({
    required this.hasEnoughData,
    required this.whatKeepsReturning,
    required this.whatChangedSince,
  });

  final bool hasEnoughData;
  final String whatKeepsReturning;
  final String whatChangedSince;

  static const insufficient = ThirdSessionArchiveUsefulness(
    hasEnoughData: false,
    whatKeepsReturning: '',
    whatChangedSince: '',
  );
}

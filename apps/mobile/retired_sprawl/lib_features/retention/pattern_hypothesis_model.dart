/// Working hypothesis after 2+ moments — conservative, not diagnostic.
class PatternHypothesis {
  const PatternHypothesis({
    required this.hasEnoughData,
    required this.patternMightBe,
    required this.evidenceSoFar,
    required this.wouldProveWrong,
    required this.watchNext,
    this.reflectionCount = 0,
  });

  factory PatternHypothesis.insufficient() {
    return const PatternHypothesis(
      hasEnoughData: false,
      patternMightBe: '',
      evidenceSoFar: [],
      wouldProveWrong: '',
      watchNext: '',
    );
  }

  final bool hasEnoughData;
  final String patternMightBe;
  final List<String> evidenceSoFar;
  final String wouldProveWrong;
  final String watchNext;
  final int reflectionCount;
}
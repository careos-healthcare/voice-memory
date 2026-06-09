/// Conservative comparison between the latest moment and the previous one.
class SecondSessionComparison {
  const SecondSessionComparison({
    required this.hasEnoughData,
    required this.title,
    required this.body,
    this.whatRepeated,
    this.whatChanged,
    this.whatToTestNext,
    this.previousSignalLabel,
    this.latestSignalLabel,
    this.possibleRepeat = false,
  });

  final bool hasEnoughData;
  final String title;
  final String body;
  final String? whatRepeated;
  final String? whatChanged;
  final String? whatToTestNext;
  final String? previousSignalLabel;
  final String? latestSignalLabel;
  final bool possibleRepeat;

  factory SecondSessionComparison.insufficient() {
    return const SecondSessionComparison(
      hasEnoughData: false,
      title: '',
      body: '',
    );
  }
}

/// User corrections ArchiveMe should respect.
class SignalCorrectionView {
  const SignalCorrectionView({
    required this.rejectedTitles,
    required this.selectedAlternativeTitle,
    required this.hasCorrections,
  });

  final List<String> rejectedTitles;
  final String? selectedAlternativeTitle;
  final bool hasCorrections;
}

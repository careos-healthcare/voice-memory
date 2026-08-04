import 'beta_report_export_copy.dart';

/// Safe beta report payload — counts and labels only, no journal text.
class BetaReportExport {
  const BetaReportExport({
    required this.title,
    required this.appOpened,
    required this.firstMomentSaved,
    required this.secondMomentSaved,
    required this.firstProofReached,
    required this.returnCheckAnswered,
    required this.proTapped,
    required this.coreValueLocalAnswer,
    required this.proofOfValueSummary,
    required this.proofOfValueRecommendation,
    required this.decisionBottleneck,
    required this.decisionFixArea,
    required this.manualQuestions,
  });

  final String title;
  final int appOpened;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int firstProofReached;
  final int returnCheckAnswered;
  final int proTapped;
  final String coreValueLocalAnswer;
  final String proofOfValueSummary;
  final String proofOfValueRecommendation;
  final String decisionBottleneck;
  final String decisionFixArea;
  final List<String> manualQuestions;

  String get formattedText => lines.join('\n');

  List<String> get lines => [
    title,
    '',
    BetaReportExportCopy.sectionTesterLoop,
    '- ${BetaReportExportCopy.rowAppOpened}: $appOpened',
    '- ${BetaReportExportCopy.rowFirstMomentSaved}: $firstMomentSaved',
    '- ${BetaReportExportCopy.rowSecondMomentSaved}: $secondMomentSaved',
    '- ${BetaReportExportCopy.rowFirstProofReached}: $firstProofReached',
    '- ${BetaReportExportCopy.rowReturnCheckAnswered}: $returnCheckAnswered',
    '- ${BetaReportExportCopy.rowProTapped}: $proTapped',
    '',
    BetaReportExportCopy.sectionCoreValue,
    '- ${BetaReportExportCopy.rowLocalAnswer}: $coreValueLocalAnswer',
    '',
    BetaReportExportCopy.sectionProofOfValue,
    '- ${BetaReportExportCopy.rowSummary}: $proofOfValueSummary',
    '- ${BetaReportExportCopy.rowRecommendation}: $proofOfValueRecommendation',
    '',
    BetaReportExportCopy.sectionDecision,
    '- ${BetaReportExportCopy.rowBottleneck}: $decisionBottleneck',
    '- ${BetaReportExportCopy.rowFixArea}: $decisionFixArea',
    '',
    BetaReportExportCopy.sectionManualQuestions,
    for (var i = 0; i < manualQuestions.length; i++)
      '${i + 1}. ${manualQuestions[i]}',
  ];
}

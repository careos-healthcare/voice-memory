import 'proof_value_bottleneck_playbook_copy.dart';

enum ProofValueBottleneckPlaybookId {
  runMoreTesters,
  fixFirstUse,
  fixReturnLoop,
  fixFirstProof,
  fixEvidence,
  strengthenRetention,
  strengthenPro,
  widenBeta,
}

/// One playbook entry — safe labels only, no journal text.
class ProofValueBottleneckPlaybookEntry {
  const ProofValueBottleneckPlaybookEntry({
    required this.id,
    required this.summaryLine,
    required this.meaning,
    required this.fixArea,
    required this.inspectSurfaces,
    required this.guardrail,
    required this.suggestedTestFiles,
  });

  final ProofValueBottleneckPlaybookId id;
  final String summaryLine;
  final String meaning;
  final String fixArea;
  final List<String> inspectSurfaces;
  final String guardrail;
  final List<String> suggestedTestFiles;

  String get testCommand => buildTestCommand(suggestedTestFiles);

  static String buildTestCommand(List<String> testFiles) {
    if (testFiles.isEmpty) return 'flutter test';
    final lines = testFiles.map((file) => '  test/$file').join(' \\\n');
    return 'flutter test \\\n$lines';
  }
}

class ProofValueBottleneckPlaybookReport {
  const ProofValueBottleneckPlaybookReport({
    required this.title,
    required this.subtitle,
    required this.activeRecommendation,
    required this.entry,
  });

  final String title;
  final String subtitle;
  final String activeRecommendation;
  final ProofValueBottleneckPlaybookEntry entry;

  List<String> get visibleCopyBlocks => [
        title,
        subtitle,
        activeRecommendation,
        entry.summaryLine,
        entry.meaning,
        entry.fixArea,
        ...entry.inspectSurfaces,
        entry.guardrail,
        ...entry.suggestedTestFiles,
        entry.testCommand,
      ];
}

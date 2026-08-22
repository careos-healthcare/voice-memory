import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';

/// Deterministic Daily Mirror output for the Record page.
class DailyMirrorResult {
  const DailyMirrorResult({
    required this.stage,
    required this.heroTitle,
    required this.heroBody,
    required this.primaryCta,
    required this.hasGroundedEvidence,
    required this.hasChange,
    required this.evidenceTerms,
    required this.evidenceEntryIds,
    this.evidenceLine,
    this.nextQuestion,
  });

  final DailyMirrorStage stage;
  final String heroTitle;
  final String heroBody;
  final String? evidenceLine;
  final String? nextQuestion;
  final String primaryCta;
  final bool hasGroundedEvidence;
  final bool hasChange;
  final List<String> evidenceTerms;
  final List<String> evidenceEntryIds;

  static const DailyMirrorResult empty = DailyMirrorResult(
    stage: DailyMirrorStage.emptyArchive,
    heroTitle: '',
    heroBody: '',
    primaryCta: '',
    hasGroundedEvidence: false,
    hasChange: false,
    evidenceTerms: [],
    evidenceEntryIds: [],
  );
}
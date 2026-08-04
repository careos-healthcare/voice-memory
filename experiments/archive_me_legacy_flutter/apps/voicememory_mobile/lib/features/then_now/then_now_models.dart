import '../archive_clarity/archive_clarity_models.dart';

/// Why a Then vs Now card is or is not shown.
enum ThenNowReasonId {
  insufficientEvidence,
  earlyPreview,
  themeComparison,
  noClearChange,
}

/// Local inputs for Then vs Now — metadata only.
class ThenNowInput {
  const ThenNowInput({
    required this.realSavedMomentCount,
    required this.usableEvidenceCount,
    this.hasWatchTheme = false,
    this.archiveClarityStage = ArchiveClarityStageId.starting,
    this.sampleMode = false,
    this.earlierThemeCounts = const {},
    this.newerThemeCounts = const {},
    this.selectedTheme,
    this.earlierMomentCount = 0,
    this.newerMomentCount = 0,
  });

  final int realSavedMomentCount;
  final int usableEvidenceCount;
  final bool hasWatchTheme;
  final ArchiveClarityStageId archiveClarityStage;
  final bool sampleMode;
  final Map<String, int> earlierThemeCounts;
  final Map<String, int> newerThemeCounts;
  final String? selectedTheme;
  final int earlierMomentCount;
  final int newerMomentCount;
}

/// Then vs Now output — summarized signals only, no journal text.
class ThenNowResult {
  const ThenNowResult({
    required this.hasCard,
    required this.headline,
    required this.thenLabel,
    required this.thenSummary,
    required this.nowLabel,
    required this.nowSummary,
    required this.evidenceCountLabel,
    required this.helperText,
    required this.cautionLabel,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.secondaryCtaLabel,
    required this.secondaryRoute,
    required this.reasonId,
    required this.showOnArchiveHome,
    this.whatThisMeans,
  });

  final bool hasCard;
  final String headline;
  final String thenLabel;
  final String thenSummary;
  final String nowLabel;
  final String nowSummary;
  final String evidenceCountLabel;
  final String helperText;
  final String cautionLabel;
  final String primaryCtaLabel;
  final String primaryRoute;
  final String secondaryCtaLabel;
  final String secondaryRoute;
  final ThenNowReasonId reasonId;
  final bool showOnArchiveHome;
  final String? whatThisMeans;

  static const empty = ThenNowResult(
    hasCard: false,
    headline: '',
    thenLabel: '',
    thenSummary: '',
    nowLabel: '',
    nowSummary: '',
    evidenceCountLabel: '',
    helperText: '',
    cautionLabel: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    secondaryCtaLabel: '',
    secondaryRoute: '',
    reasonId: ThenNowReasonId.insufficientEvidence,
    showOnArchiveHome: false,
  );
}

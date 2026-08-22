import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';

/// Inputs for deterministic Pro value packaging — metadata only.
class ProValueInput {
  const ProValueInput({
    required this.savedEntryCount,
    required this.depthLevel,
    required this.watchlistCount,
    required this.weeklyReviewAvailable,
    required this.evidenceMapContextCount,
    required this.beliefHistoryAvailable,
    required this.purchasesAvailable,
  });

  final int savedEntryCount;
  final ArchiveDepthLevel depthLevel;
  final int watchlistCount;
  final bool weeklyReviewAvailable;
  final int evidenceMapContextCount;
  final bool beliefHistoryAvailable;
  final bool purchasesAvailable;
}

/// Navigation target for Pro value CTAs.
class ProValueCTA {
  const ProValueCTA({required this.label, required this.route});

  final String label;
  final String route;
}

/// Deterministic Pro value readout for preview and archive touchpoints.
class ProValuePlan {
  const ProValuePlan({
    required this.headline,
    required this.subheadline,
    required this.body,
    required this.valueBullets,
    required this.freeNowBullets,
    required this.purchaseUnavailableNote,
    required this.purchaseKeepFreeNote,
    required this.purchaseAfterSetupNote,
    required this.primaryCta,
    required this.secondaryCta,
    required this.cardProLine,
    required this.whyBodyOne,
    required this.whyBodyTwo,
  });

  final String headline;
  final String subheadline;
  final String body;
  final List<String> valueBullets;
  final List<String> freeNowBullets;
  final String purchaseUnavailableNote;
  final String purchaseKeepFreeNote;
  final String purchaseAfterSetupNote;
  final ProValueCTA primaryCta;
  final ProValueCTA secondaryCta;
  final String cardProLine;
  final String whyBodyOne;
  final String whyBodyTwo;
}
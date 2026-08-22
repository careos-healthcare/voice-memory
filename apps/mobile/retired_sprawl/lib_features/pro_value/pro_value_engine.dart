import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_models.dart';

/// Deterministic Pro value packaging — local, no persistence.
class ProValueEngine {
  const ProValueEngine();

  ProValuePlan build(ProValueInput input) {
    return ProValuePlan(
      headline: ProValueCopy.headline,
      subheadline: ProValueCopy.subheadline,
      body: ProValueCopy.body,
      valueBullets: ProValueCopy.valueBullets,
      freeNowBullets: ProValueCopy.freeNowBullets,
      purchaseUnavailableNote: input.purchasesAvailable
          ? ProValueCopy.purchaseAfterSetupNote
          : ProValueCopy.purchaseUnavailableNote,
      purchaseKeepFreeNote: ProValueCopy.purchaseKeepFreeNote,
      purchaseAfterSetupNote: ProValueCopy.purchaseAfterSetupNote,
      primaryCta: const ProValueCTA(
        label: ProValueCopy.primaryCtaLabel,
        route: ProValueCopy.primaryCtaRoute,
      ),
      secondaryCta: const ProValueCTA(
        label: ProValueCopy.secondaryCtaLabel,
        route: ProValueCopy.secondaryCtaRoute,
      ),
      cardProLine: ProValueCopy.cardProLine,
      whyBodyOne: ProValueCopy.whyBodyOne,
      whyBodyTwo: _whyBodyTwo(input),
    );
  }

  static String _whyBodyTwo(ProValueInput input) {
    if (input.savedEntryCount >= 10 ||
        input.depthLevel == ArchiveDepthLevel.longTermBuilding) {
      return 'At this stage, a longer evidence history helps you compare what '
          'kept repeating and what changed across months — that is what Pro '
          'is designed for.';
    }
    if (input.weeklyReviewAvailable || input.savedEntryCount >= 5) {
      return 'As weekly reviews and watch themes accumulate, Pro helps you '
          'keep a longer view without losing earlier evidence.';
    }
    return ProValueCopy.whyBodyTwo;
  }
}
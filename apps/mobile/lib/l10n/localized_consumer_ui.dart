import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations_en.dart';
import 'package:flutter/widgets.dart';

/// English fallback for tests, analytics, and copy classes without [BuildContext].
AppLocalizations get englishLocalizations => AppLocalizationsEn();

/// Locale-aware access for account, record, paywall, and patterns surfaces.
extension LocalizedConsumerUi on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Paywall source copy resolved from [AppLocalizations].
class LocalizedPaywallCopy {
  const LocalizedPaywallCopy({
    required this.headline,
    required this.subheadline,
    required this.bullets,
    required this.cta,
  });

  final String headline;
  final String subheadline;
  final List<String> bullets;
  final String cta;

  factory LocalizedPaywallCopy.from(AppLocalizations l10n) =>
      LocalizedPaywallCopy(
        headline: l10n.paywallHeadline,
        subheadline: l10n.paywallSubhead,
        bullets: [
          l10n.paywallBenefitBullet1,
          l10n.paywallBenefitBullet2,
          l10n.paywallBenefitBullet3,
        ],
        cta: l10n.paywallPrimaryCta,
      );
}

/// Value-moment Pro bridge copy resolved from [AppLocalizations].
class LocalizedValueMomentBridge {
  const LocalizedValueMomentBridge({
    required this.title,
    required this.ctaLabel,
    required this.dismissLabel,
    required this.threadReturnBody,
    required this.beliefBody,
    required this.weeklyBody,
    required this.proofCounterBody,
    required this.fallbackBody,
  });

  final String title;
  final String ctaLabel;
  final String dismissLabel;
  final String threadReturnBody;
  final String beliefBody;
  final String weeklyBody;
  final String proofCounterBody;
  final String fallbackBody;

  factory LocalizedValueMomentBridge.from(AppLocalizations l10n) =>
      LocalizedValueMomentBridge(
        title: l10n.valueMomentProTitle,
        ctaLabel: l10n.valueMomentProCta,
        dismissLabel: l10n.valueMomentProDismiss,
        threadReturnBody: l10n.valueMomentThreadReturnBody,
        beliefBody: l10n.valueMomentBeliefBody,
        weeklyBody: l10n.valueMomentWeeklyBody,
        proofCounterBody: l10n.valueMomentProofCounterBody,
        fallbackBody: l10n.valueMomentFallbackBody,
      );

  String bodyForCardType(String cardType) => switch (cardType) {
        'thread_return' => threadReturnBody,
        'belief_distance' => beliefBody,
        'weekly_thread_review' => weeklyBody,
        'archive_proof_counter' => proofCounterBody,
        _ => fallbackBody,
      };
}
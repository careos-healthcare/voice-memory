import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// RevenueCat offering id for the capped founder lifetime product.
const founderLifetimeOfferingId = 'founder_lifetime';

/// Shown only when [founderLifetimeOfferingId] is present in the offerings map.
const founderLifetimeCap = 500;

/// True when RevenueCat returned the founder lifetime offering.
bool founderLifetimeOfferingExists(Iterable<String> offeringIds) {
  return offeringIds.contains(founderLifetimeOfferingId);
}

/// Paywall after first proof. Sells keeping the longer story.
class LongerStoryPaywall extends StatelessWidget {
  const LongerStoryPaywall({
    required this.patternTitle,
    required this.quotes,
    this.annualPrice = '£39.99/year',
    this.monthlyPrice = '£4.99/month',
    this.founderLifetimePrice,
    this.purchaseAllowed = true,
    this.onRestore,
    this.onTerms,
    this.onPrivacy,
    this.onPurchase,
    super.key,
  });

  final String patternTitle;
  final List<String> quotes;
  final String annualPrice;
  final String monthlyPrice;
  final String? founderLifetimePrice;
  final bool purchaseAllowed;
  final VoidCallback? onRestore;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;
  final VoidCallback? onPurchase;

  static const headline = 'Keep the longer story';
  static const freeKeeps = 'Free keeps: all entries, export, deletion';
  static const proKeeps =
      'Pro keeps: full pattern history, change timeline, private reports, book export';
  static const annualTitle = 'Annual';
  static const monthlyTitle = 'Monthly';
  static const restoreLabel = 'Restore purchases';
  static const termsLabel = 'Terms';
  static const privacyLabel = 'Privacy';
  static const purchaseLabel = 'Continue with annual';

  static const reviewPattern = 'Saying no when the invite lands';
  static const reviewQuotes = [
    'I keep telling myself I want to speak, then I find a reason to say no.',
    'It is the same story as last quarter.',
  ];

  @override
  Widget build(BuildContext context) {
    final quoteStyle = ArchiveMobileTypography.explanationBody(context);
    return ColoredBox(
      color: const Color(0xFFF7F1E8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              headline,
              style: ArchiveMobileTypography.responsivePageTitle(context),
            ),
            const SizedBox(height: 16),
            Text(
              patternTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: 10),
            for (final quote in quotes.take(2)) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E6D4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC4A484),
                    width: 1.5,
                  ),
                ),
                child: Text(quote, style: quoteStyle),
              ),
            ],
            const SizedBox(height: 12),
            Text(freeKeeps, style: quoteStyle),
            const SizedBox(height: 8),
            Text(proKeeps, style: quoteStyle),
            const SizedBox(height: 18),
            _PlanLine(
              title: annualTitle,
              price: annualPrice,
              detail: monthlyPrice,
              selected: true,
            ),
            const SizedBox(height: 8),
            _PlanLine(
              title: monthlyTitle,
              price: monthlyPrice,
              selected: false,
            ),
            if (founderLifetimePrice != null) ...[
              const SizedBox(height: 8),
              _PlanLine(
                title: 'Founder lifetime · first $founderLifetimeCap',
                price: founderLifetimePrice!,
                selected: false,
              ),
            ],
            if (purchaseAllowed) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onPurchase,
                child: const Text(purchaseLabel),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onRestore,
                  child: const Text(restoreLabel),
                ),
                TextButton(
                  onPressed: onTerms,
                  child: const Text(termsLabel),
                ),
                TextButton(
                  onPressed: onPrivacy,
                  child: const Text(privacyLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({
    required this.title,
    required this.price,
    required this.selected,
    this.detail,
  });

  final String title;
  final String price;
  final String? detail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF8C5A3C) : AppColors.borderSubtle,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

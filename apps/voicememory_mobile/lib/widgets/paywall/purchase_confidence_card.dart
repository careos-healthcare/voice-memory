import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/purchase_confidence/purchase_confidence_analytics.dart';
import '../../features/purchase_confidence/purchase_confidence_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Privacy and control reassurance near the paywall purchase decision.
class PurchaseConfidenceCard extends StatefulWidget {
  const PurchaseConfidenceCard({
    super.key,
    required this.source,
    required this.surface,
    this.entryCount,
  });

  final String source;
  final String surface;
  final int? entryCount;

  @override
  State<PurchaseConfidenceCard> createState() => _PurchaseConfidenceCardState();
}

class _PurchaseConfidenceCardState extends State<PurchaseConfidenceCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    PurchaseConfidenceAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      entryCount: widget.entryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final footerStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('purchase_confidence_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PurchaseConfidenceCopy.cardTitle,
            key: const Key('purchase_confidence_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PurchaseConfidenceCopy.body,
            key: const Key('purchase_confidence_body'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in PurchaseConfidenceCopy.trustBullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    bullet,
                    key: Key('purchase_confidence_bullet_$bullet'),
                    style: bodyStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            PurchaseConfidenceCopy.footer,
            key: const Key('purchase_confidence_footer'),
            style: footerStyle,
          ),
        ],
      ),
    );
  }
}

/// Compact trust line for Pro bridge cards — not the full purchase-confidence card.
class PurchaseConfidenceCompactLine extends StatelessWidget {
  const PurchaseConfidenceCompactLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      PurchaseConfidenceCopy.compactTrustLine,
      key: const Key('purchase_confidence_compact_trust'),
      style: ArchiveMobileTypography.responsiveHelper(
        context,
      ).copyWith(color: AppColors.textSecondary, height: 1.4),
    );
  }
}

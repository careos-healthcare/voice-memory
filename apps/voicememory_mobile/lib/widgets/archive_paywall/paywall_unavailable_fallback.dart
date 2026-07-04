import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/pro_packaging/pro_value_copy.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/voicememory_colors.dart';

/// Polished paywall when subscription plans are unavailable.
class PaywallUnavailableFallback extends StatelessWidget {
  const PaywallUnavailableFallback({
    super.key,
    required this.body,
    this.headline,
    this.subhead,
    this.onRestore,
    this.busy = false,
    this.showRetry = false,
    this.onRetry,
    this.hideBenefits = false,
  });

  final String body;

  /// Source-aware headline; defaults to the general paywall headline.
  final String? headline;

  /// Optional source-aware subheadline shown above [body].
  final String? subhead;
  final VoidCallback? onRestore;
  final bool busy;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool hideBenefits;

  static const List<String> benefits = ConsumerUiCopy.paywallFallbackBullets;

  @override
  Widget build(BuildContext context) {
    return ArchiveResponsiveLayout.constrainContent(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            headline ?? ConsumerUiCopy.paywallHeadline,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
            textAlign: TextAlign.center,
          ),
          if (subhead != null) ...[
            const SizedBox(height: 10),
            Text(
              subhead!,
              style: ArchiveMobileTypography.responsiveBody(context),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            body,
            style: ArchiveMobileTypography.responsiveBody(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (!hideBenefits)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VoiceMemoryColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VoiceMemoryColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final benefit in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: VoiceMemoryColors.primaryIndigo,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              benefit,
                              style: ArchiveMobileTypography.responsiveBody(
                                context,
                                color: VoiceMemoryColors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (!hideBenefits) const SizedBox(height: 16),
          if (showRetry) ...[
            OutlinedButton(
              onPressed: busy ? null : onRetry,
              child: const Text('Try again'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () => context.pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              hideBenefits ? ProPackagingCopy.continueCta : 'Done',
              style: ArchiveMobileTypography.responsiveCta(context),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onRestore,
            child: Text(ConsumerUiCopy.restorePurchases),
          ),
        ],
      ),
    );
  }
}

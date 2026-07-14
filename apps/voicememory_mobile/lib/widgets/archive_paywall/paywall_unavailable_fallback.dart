import 'package:flutter/material.dart';

import '../../billing/paywall_unavailable_state.dart';
import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/voicememory_colors.dart';

/// Polished paywall when subscription plans are unavailable.
class PaywallUnavailableFallback extends StatelessWidget {
  const PaywallUnavailableFallback({
    super.key,
    required this.body,
    required this.onDismiss,
    this.headline,
    this.subhead,
    this.onRestore,
    this.busy = false,
    this.showRetry = false,
    this.onRetry,
    this.retrying = false,
    this.hideBenefits = false,
    this.primaryDismissLabel,
  });

  final String body;

  /// Source-aware headline; defaults to the general paywall headline.
  final String? headline;

  /// Optional source-aware subheadline shown above [body].
  final String? subhead;
  final VoidCallback onDismiss;
  final VoidCallback? onRestore;
  final bool busy;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool retrying;
  final bool hideBenefits;
  final String? primaryDismissLabel;

  static const List<String> benefits = ConsumerUiCopy.paywallFallbackBullets;

  String get _dismissLabel =>
      primaryDismissLabel ??
      PaywallUnavailableState.primaryDismissLabel(hideBenefits: hideBenefits);

  Key get _dismissButtonKey => Key(
        hideBenefits
            ? 'paywall_unavailable_continue_without_pro'
            : 'paywall_unavailable_done',
      );

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
            key: const Key('paywall_unavailable_body'),
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
              key: const Key('paywall_unavailable_try_again'),
              onPressed: retrying ? null : onRetry,
              child: retrying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(PaywallUnavailableState.tryAgainLabel),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: _dismissButtonKey,
            onPressed: busy ? null : onDismiss,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _dismissLabel,
              style: ArchiveMobileTypography.responsiveCta(context),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('paywall_unavailable_restore'),
            onPressed: busy ? null : onRestore,
            child: Text(ConsumerUiCopy.restorePurchases),
          ),
        ],
      ),
    );
  }
}

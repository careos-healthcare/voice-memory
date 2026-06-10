import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../billing/paywall_route_args.dart';
import '../../features/pressure_retention/start_here_save_receipt_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

/// Compact post-save receipt for recordings that started from Start here
/// today or a Daily Suggestion.
///
/// Shows what the recording connected to, then offers a soft Pro CTA that
/// routes to the paywall with the right source. Never opens the paywall on
/// its own and never blocks recording again — dismissing simply hides it.
class StartHereSaveReceiptCard extends StatelessWidget {
  const StartHereSaveReceiptCard({
    super.key,
    required this.receipt,
    required this.onDismiss,
  });

  final StartHereSaveReceipt receipt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('start_here_save_receipt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.title,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            receipt.explanation,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (receipt.connectedTerms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final term in receipt.connectedTerms)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.borderSubtle),
                      color: Colors.white,
                    ),
                    child: Text(
                      term,
                      style: VoiceMemoryTypography.metadataStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('save_receipt_pro_cta'),
                  // Compact override: the app-wide FilledButton theme is
                  // full-width, which cannot live inside this Row.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => context.push(
                    '/subscription',
                    extra: PaywallRouteArgs(
                      source: receipt.paywallSource,
                      sourceRoute: '/record',
                    ),
                  ),
                  child: Text(
                    receipt.proCtaLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('save_receipt_dismiss'),
                onPressed: onDismiss,
                child: Text(receipt.dismissLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

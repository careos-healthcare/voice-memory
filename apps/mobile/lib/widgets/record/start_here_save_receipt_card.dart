import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/features/pressure_retention/start_here_save_receipt_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact post-save receipt for recordings that started from Start here
/// today or a Daily Suggestion.
///
/// Shows what the recording connected to, then offers a soft Pro CTA that
/// routes to the paywall with the right source. Never opens the paywall on
/// its own and never blocks recording again — dismissing simply hides it.
class StartHereSaveReceiptCard extends StatelessWidget {
  const StartHereSaveReceiptCard({
    required this.receipt, required this.onDismiss, super.key,
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
          // Tomorrow's return cue sits between the user's terms and the Pro
          // incentive — cautious phrasing, never a promise.
          const SizedBox(height: AppSpacing.xs),
          Text(
            receipt.returnCueLine,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          // Free value first, so Pro reads as a continuation — never as a
          // threat to what the user just saved.
          const SizedBox(height: AppSpacing.xs),
          Text(
            receipt.freeValueLine,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            receipt.proContinuationLine,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (receipt.proPreviewBullets.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final bullet in receipt.proPreviewBullets)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u2022 ',
                      style: VoiceMemoryTypography.metadataStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        bullet,
                        style: VoiceMemoryTypography.metadataStyle(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
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
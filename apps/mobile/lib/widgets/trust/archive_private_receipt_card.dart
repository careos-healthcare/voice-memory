import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/trust/archive_trust_receipt.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Small trust receipt after an important save — once per session max.
class ArchivePrivateReceiptCard extends StatelessWidget {
  const ArchivePrivateReceiptCard({
    required this.entryCount, required this.onDismiss, super.key,
    this.source = 'record',
  });

  final int entryCount;
  final VoidCallback onDismiss;
  final String source;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archivePrivateReceiptSeen,
      entryCount: entryCount,
      source: source,
      stage: ArchiveTrustReceipt.pendingStage ?? ProTrustStage.seriousUse,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );
    ArchiveTrustReceipt.markShown();

    return Container(
      key: const Key('archive_private_receipt_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F7FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProTrustCopy.receiptTitle,
            key: const Key('archive_private_receipt_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProTrustCopy.receiptBody,
            key: const Key('archive_private_receipt_body'),
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_private_receipt_not_now'),
                  onPressed: () {
                    ArchiveTrustReceipt.dismiss();
                    onDismiss();
                  },
                  child: const Text(ProTrustCopy.receiptNotNow),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('archive_private_receipt_review'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics
                          .archivePrivateReceiptReviewTapped,
                      entryCount: entryCount,
                      source: source,
                      stage:
                          ArchiveTrustReceipt.pendingStage ??
                          ProTrustStage.seriousUse,
                      memoryScope: MemoryScopePolicy.scope.id,
                    );
                    unawaited(context.push('/settings'));
                  },
                  child: const Text(ProTrustCopy.receiptReviewCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
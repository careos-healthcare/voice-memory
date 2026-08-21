import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/trust/capture_recovery_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Calm one-line recovery hint — no extra CTAs, capture-first.
class CaptureRecoveryHintStrip extends StatelessWidget {
  const CaptureRecoveryHintStrip({
    required this.title, required this.body, super.key,
    this.hintKey,
  });

  const CaptureRecoveryHintStrip.returnedAfterDelay({super.key})
    : title = CaptureRecoveryCopy.returnedAfterDelayTitle,
      body = CaptureRecoveryCopy.returnedAfterDelayBody,
      hintKey = const Key('capture_recovery_returned_after_delay');

  const CaptureRecoveryHintStrip.testBuildEntitlement({super.key})
    : title = '',
      body = CaptureRecoveryCopy.testBuildEntitlementTimeout,
      hintKey = const Key('capture_recovery_test_build_entitlement');

  const CaptureRecoveryHintStrip.testBuildNetwork({super.key})
    : title = '',
      body = CaptureRecoveryCopy.testBuildNetworkUnavailable,
      hintKey = const Key('capture_recovery_test_build_network');

  final String title;
  final String body;
  final Key? hintKey;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Padding(
      key: hintKey,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              key: const Key('capture_recovery_hint_title'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            body,
            key: const Key('capture_recovery_hint_body'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
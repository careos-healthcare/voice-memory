import 'package:flutter/material.dart';

import '../../onboarding/onboarding_visuals.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'remote_processing_consent_copy.dart';

/// The explicit, first-use remote-processing consent prompt shown as the
/// final onboarding step, before the customer's first save could ever be
/// analyzed remotely.
///
/// Neither choice is preselected — [onDecision] is only ever called from an
/// explicit tap on one of the two buttons, never from a default or a timer.
class RemoteProcessingConsentStep extends StatelessWidget {
  const RemoteProcessingConsentStep({
    super.key,
    required this.onDecision,
    this.submitting = false,
  });

  /// Called with `true` for "allow" or `false` for "decline". The caller is
  /// responsible for persisting the decision and advancing past this step.
  final ValueChanged<bool> onDecision;

  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: OnboardingLayout.maxContentWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  RemoteProcessingConsentCopy.title,
                  style: OnboardingTypography.title(context),
                ),
                SizedBox(height: OnboardingTypography.sectionGap(context)),
                Text(
                  RemoteProcessingConsentCopy.body,
                  style: OnboardingTypography.body(context),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ConsentDetailRow(
                        text: RemoteProcessingConsentCopy.detailBullet1,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      _ConsentDetailRow(
                        text: RemoteProcessingConsentCopy.detailBullet2,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      _ConsentDetailRow(
                        text: RemoteProcessingConsentCopy.detailBullet3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('remote_processing_consent_allow'),
                  onPressed: submitting ? null : () => onDecision(true),
                  child: const Text(RemoteProcessingConsentCopy.allowCta),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('remote_processing_consent_decline'),
                  onPressed: submitting ? null : () => onDecision(false),
                  child: const Text(RemoteProcessingConsentCopy.declineCta),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  RemoteProcessingConsentCopy.declinedFootnote,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConsentDetailRow extends StatelessWidget {
  const _ConsentDetailRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 8),
          child: Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

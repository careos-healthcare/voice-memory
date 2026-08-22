import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Explicit first-use remote-processing consent — final onboarding step.
class RemoteProcessingConsentStep extends StatelessWidget {
  const RemoteProcessingConsentStep({
    required this.onDecision,
    super.key,
    this.submitting = false,
  });

  final ValueChanged<bool> onDecision;
  final bool submitting;

  static const _buttonStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
  );

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
                Semantics(
                  header: true,
                  child: Text(
                    RemoteProcessingConsentCopy.title,
                    style: OnboardingTypography.title(context),
                  ),
                ),
                SizedBox(height: OnboardingTypography.sectionGap(context)),
                const OnDeviceArchitectureSection(
                  useOnboardingTypography: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    RemoteProcessingConsentCopy.detailsHeading,
                    style: OnboardingTypography.label(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    RemoteProcessingConsentCopy.settingChangeHeading,
                    style: OnboardingTypography.label(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  RemoteProcessingConsentCopy.settingChangeBody,
                  key: Key('remote_processing_consent_setting_change'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  RemoteProcessingConsentCopy.settingChangeScope,
                  key: Key('remote_processing_consent_setting_scope'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('remote_processing_consent_more_detail'),
                    onPressed: submitting ? null : () => context.push('/privacy'),
                    child: const Text(RemoteProcessingConsentCopy.moreDetailLink),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const Key('remote_processing_consent_allow'),
                  style: _buttonStyle,
                  onPressed: submitting ? null : () => onDecision(true),
                  child: const Text(RemoteProcessingConsentCopy.allowCta),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('remote_processing_consent_decline'),
                  style: _buttonStyle,
                  onPressed: submitting ? null : () => onDecision(false),
                  child: const Text(RemoteProcessingConsentCopy.declineCta),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
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

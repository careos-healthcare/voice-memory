import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// First-run send choice — two buttons, no policy essay.
class RemoteProcessingConsentStep extends StatelessWidget {
  const RemoteProcessingConsentStep({
    required this.onDecision,
    super.key,
    this.submitting = false,
    this.showActions = true,
  });

  final ValueChanged<bool> onDecision;
  final bool submitting;

  /// When false, [OnboardingScreen] owns the buttons so progress dots
  /// sit in the same chrome as screen 1.
  final bool showActions;

  static const buttonStyle = ButtonStyle(
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
              minHeight: showActions ? constraints.maxHeight : 0,
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
                Text(
                  RemoteProcessingConsentCopy.body,
                  style: OnboardingTypography.body(context),
                ),
                if (showActions) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    RemoteProcessingConsentCopy.changeLaterFootnote,
                    key: Key('remote_processing_consent_change_later'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    key: const Key('remote_processing_consent_allow'),
                    style: buttonStyle,
                    onPressed: submitting ? null : () => onDecision(true),
                    child: const Text(RemoteProcessingConsentCopy.allowCta),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const Key('remote_processing_consent_decline'),
                    style: buttonStyle,
                    onPressed: submitting ? null : () => onDecision(false),
                    child: const Text(RemoteProcessingConsentCopy.declineCta),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

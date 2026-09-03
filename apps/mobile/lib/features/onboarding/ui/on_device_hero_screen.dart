import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Confirms the remote-processing choice, then starts the archive.
class OnDeviceHeroScreen extends StatelessWidget {
  const OnDeviceHeroScreen({
    required this.allowedRemote,
    required this.onContinue,
    super.key,
    this.submitting = false,
  });

  /// The consent answer this screen is confirming.
  final bool allowedRemote;

  /// Proceeds into the app. This is the only forward path from this screen.
  final VoidCallback onContinue;

  /// Disables the start action while onboarding completion is in flight.
  final bool submitting;

  static const Key screenKey = Key('on_device_hero_screen');
  static const Key panelKey = Key('on_device_hero_panel');
  static const Key titleKey = Key('on_device_hero_title');
  static const Key bodyKey = Key('on_device_hero_body');
  static const Key continueKey = Key('on_device_hero_continue');

  static const Color _panelSurface = AppColors.textPrimary;
  static const Color _panelText = AppColors.backgroundSecondary;

  @override
  Widget build(BuildContext context) {
    final title = OnDeviceHeroCopy.titleFor(allowedRemote: allowedRemote);
    final body = OnDeviceHeroCopy.bodyFor(allowedRemote: allowedRemote);

    return Column(
      key: screenKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingLayout.maxContentWidth,
                ),
                child: Container(
                  key: panelKey,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _panelSurface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _panelSurface.withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          key: titleKey,
                          style: OnboardingTypography.title(
                            context,
                            color: _panelText,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        key: bodyKey,
                        style: OnboardingTypography.body(
                          context,
                          color: _panelText.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: FilledButton(
            key: continueKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.onAccent,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: submitting ? null : onContinue,
            child: const Text(OnDeviceHeroCopy.continueCta),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/encryption_status_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The on-device architecture hero — the last onboarding screen before the
/// customer reaches `/record`.
///
/// Visually this is the one inverted surface in onboarding: a dark panel
/// carrying three light-on-dark trust badges, so it reads as a statement rather
/// than as another step in the same cream flow. Everything it says comes from
/// [OnDeviceHeroCopy], which takes its pillars verbatim from the shared
/// settings statement.
///
/// One thing here is deliberately *not* copy: [EncryptionStatusCard] renders
/// `SecureSqliteLockService.encryptionEnabled` live, so a build without
/// encryption says so on this screen instead of being contradicted by it.
class OnDeviceHeroScreen extends StatelessWidget {
  const OnDeviceHeroScreen({
    required this.onContinue,
    super.key,
    this.submitting = false,
    this.onSeeDetails,
  });

  /// Proceeds into the app. This is the only forward path from this screen.
  final VoidCallback onContinue;

  /// Disables both actions while onboarding completion is in flight.
  final bool submitting;

  /// Overrides the `/privacy` push, so widget tests can pump this screen
  /// without a router.
  final VoidCallback? onSeeDetails;

  static const Key screenKey = Key('on_device_hero_screen');
  static const Key panelKey = Key('on_device_hero_panel');
  static const Key eyebrowKey = Key('on_device_hero_eyebrow');
  static const Key titleKey = Key('on_device_hero_title');
  static const Key ledeKey = Key('on_device_hero_lede');
  static const Key storageStatusKey = Key('on_device_hero_storage_status');
  static const Key detailLinkKey = Key('on_device_hero_detail_link');
  static const Key continueKey = Key('on_device_hero_continue');

  static Key pillarKey(int index) => Key('on_device_hero_pillar_$index');

  /// Light-on-dark palette for the inverted panel. `AppColors.accentPrimary`
  /// is a mid blue that does not carry on a dark ground, so the accent here is
  /// the light tint instead.
  static const Color _panelSurface = AppColors.textPrimary;
  static const Color _panelText = AppColors.backgroundSecondary;
  static const Color _panelAccent = AppColors.accentLight;

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HeroPanel(),
                    const SizedBox(height: AppSpacing.md),
                    const _StorageStatus(),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: detailLinkKey,
                        onPressed: submitting
                            ? null
                            : () => _seeDetails(context),
                        child: const Text(OnDeviceHeroCopy.detailLink),
                      ),
                    ),
                  ],
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

  void _seeDetails(BuildContext context) {
    final override = onSeeDetails;
    if (override != null) {
      override();
      return;
    }
    unawaited(context.push('/privacy'));
  }
}

/// The inverted hero panel: eyebrow, title, lede, then the three badges.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: OnDeviceHeroScreen.panelKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: OnDeviceHeroScreen._panelSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: OnDeviceHeroScreen._panelSurface.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            OnDeviceHeroCopy.eyebrow.toUpperCase(),
            key: OnDeviceHeroScreen.eyebrowKey,
            style: OnboardingTypography.label(
              color: OnDeviceHeroScreen._panelAccent,
            ).copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              OnDeviceHeroCopy.title,
              key: OnDeviceHeroScreen.titleKey,
              style: OnboardingTypography.title(
                context,
                color: OnDeviceHeroScreen._panelText,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            OnDeviceHeroCopy.lede,
            key: OnDeviceHeroScreen.ledeKey,
            style: OnboardingTypography.body(
              context,
              color: OnDeviceHeroScreen._panelText.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < OnDeviceHeroCopy.pillars.length; i++) ...[
            _TrustBadge(
              index: i + 1,
              title: OnDeviceHeroCopy.pillars[i].title,
              body: OnDeviceHeroCopy.pillars[i].body,
            ),
            if (i < OnDeviceHeroCopy.pillars.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// One high-contrast trust badge on the inverted panel.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.index,
    required this.title,
    required this.body,
  });

  final int index;
  final String title;
  final String body;

  static const List<IconData> _icons = [
    Icons.memory_outlined,
    Icons.cloud_off_outlined,
    Icons.query_stats_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      // One node per badge: the label already carries both lines, so letting
      // the children speak too would read every badge twice.
      excludeSemantics: true,
      label: '$title. $body',
      child: Container(
        key: OnDeviceHeroScreen.pillarKey(index),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: OnDeviceHeroScreen._panelText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: OnDeviceHeroScreen._panelAccent.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OnDeviceHeroScreen._panelAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                _icons[(index - 1) % _icons.length],
                size: 18,
                color: OnDeviceHeroScreen._panelAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: OnboardingTypography.label(
                      color: OnDeviceHeroScreen._panelText,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: OnboardingTypography.body(
                      context,
                      color: OnDeviceHeroScreen._panelText.withValues(
                        alpha: 0.76,
                      ),
                    ).copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live storage-protection status, framed rather than asserted.
class _StorageStatus extends StatelessWidget {
  const _StorageStatus();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: OnDeviceHeroScreen.storageStatusKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            OnDeviceHeroCopy.storageStatusHeading,
            style: OnboardingTypography.label(color: AppColors.accentPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          OnDeviceHeroCopy.storageStatusBody,
          style: OnboardingTypography.body(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const EncryptionStatusCard(),
      ],
    );
  }
}

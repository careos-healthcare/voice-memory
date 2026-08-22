import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_grant_list.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Canonical control surface for caregiver and coach access.
///
/// The consent audit trail deliberately stays on its own `/consent-audit`
/// route and is linked from here rather than folded in: this screen is only
/// discoverable while `V1CapabilityRegistry.caregiverMonitoring` is on, and a
/// token issued before the flag flipped off keeps verifying for the rest of
/// its TTL, so the surface that lists and revokes historical grants must not
/// disappear with the flag.
class CaregiverAccessScreen extends StatelessWidget {
  const CaregiverAccessScreen({
    super.key,
    this.accessService,
    this.confirmRevokeOverride,
  });

  final MultiPartyAccessService? accessService;

  @visibleForTesting
  final Future<bool> Function(
    BuildContext context,
    MultiPartyAccessGrant grant,
  )? confirmRevokeOverride;

  static const Key screenKey = Key('caregiver_access_screen');

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CaregiverAccessCopy.screenTitle,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          key: screenKey,
          padding: EdgeInsets.zero,
          children: [
            const _ControlCallout(),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeading(text: CaregiverAccessCopy.canSeeHeading),
            const SizedBox(height: AppSpacing.sm),
            const _CanSeeBlock(
              title: CaregiverAccessCopy.caregiverCanSeeTitle,
              body: CaregiverAccessCopy.caregiverCanSeeBody,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _CanSeeBlock(
              title: CaregiverAccessCopy.coachCanSeeTitle,
              body: CaregiverAccessCopy.coachCanSeeBody,
            ),
            const SizedBox(height: AppSpacing.md),
            const _CanSeeBlock(
              key: Key('caregiver_access_scope_note'),
              title: CaregiverAccessCopy.scopeNoteHeading,
              body: CaregiverAccessCopy.scopeNoteBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeading(text: CaregiverAccessCopy.cannotSeeHeading),
            const SizedBox(height: AppSpacing.sm),
            const _BulletBlock(items: CaregiverAccessCopy.cannotSeeBullets),
            const SizedBox(height: AppSpacing.md),
            const _CanSeeBlock(
              key: Key('caregiver_access_intent_note'),
              title: CaregiverAccessCopy.intentHeading,
              body: CaregiverAccessCopy.intentBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeading(text: CaregiverAccessCopy.activeGrantsHeading),
            const SizedBox(height: AppSpacing.sm),
            CaregiverAccessGrantList(
              accessService: accessService,
              confirmRevokeOverride: confirmRevokeOverride,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              key: const Key('caregiver_access_consent_audit_link'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                CaregiverAccessCopy.auditTrailLinkTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                CaregiverAccessCopy.auditTrailLinkSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/consent-audit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlCallout extends StatelessWidget {
  const _ControlCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('caregiver_access_control_callout'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.accentPrimary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CaregiverAccessCopy.controlHeading,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                const SizedBox(height: 4),
                Text(
                  CaregiverAccessCopy.controlBody,
                  style: ArchiveMobileTypography.listSubtitle(context).copyWith(
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ArchiveMobileTypography.cardLabel(context).copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CanSeeBlock extends StatelessWidget {
  const _CanSeeBlock({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(
            body,
            style: ArchiveMobileTypography.listSubtitle(context).copyWith(
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletBlock extends StatelessWidget {
  const _BulletBlock({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = ArchiveMobileTypography.listSubtitle(context).copyWith(
      height: 1.45,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

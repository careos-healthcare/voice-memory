import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_entry_point.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_flow.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// Settings surface for caregiver consent: grant, status, and revoke.
///
/// The master switch starts [CaregiverGrantFlow] (disclosure then form) when
/// turning on, and the existing revoke path when turning off. Granular rows
/// are disabled labels — mood trends, crisis alerts, and check-in requests
/// are not working controls in this build.
class CaregiverConsentScreen extends StatefulWidget {
  const CaregiverConsentScreen({
    super.key,
    this.accessService,
    this.confirmRevokeOverride,
  });

  final MultiPartyAccessService? accessService;

  @visibleForTesting
  final Future<bool> Function(BuildContext context)? confirmRevokeOverride;

  static const Key screenKey = Key('caregiver_consent_screen');
  static const Key bannerKey = Key('caregiver_consent_banner');
  static const Key masterSwitchKey = Key('caregiver_consent_master_switch');
  static const Key revokeKey = Key('caregiver_consent_revoke');
  static const Key moodRowKey = Key('caregiver_consent_row_mood');
  static const Key alertsRowKey = Key('caregiver_consent_row_alerts');
  static const Key checkInsRowKey = Key('caregiver_consent_row_checkins');

  @override
  State<CaregiverConsentScreen> createState() => _CaregiverConsentScreenState();
}

class _CaregiverConsentScreenState extends State<CaregiverConsentScreen> {
  List<MultiPartyAccessGrant> _grants = const [];
  bool _loading = true;
  bool _busy = false;

  MultiPartyAccessService get _service =>
      widget.accessService ?? MultiPartyAccessService();

  List<MultiPartyAccessGrant> get _caregiverGrants => _grants
      .where((grant) => grant.role == MultiPartyAccessRole.caregiver)
      .toList(growable: false);

  bool get _accessOn => _caregiverGrants.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final grants = await _service.loadActiveGrants();
    if (!mounted) return;
    setState(() {
      _grants = grants;
      _loading = false;
    });
  }

  Future<void> _onMasterChanged(bool enable) async {
    if (_busy || _loading) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await CaregiverGrantFlow.start(context);
      } finally {
        if (mounted) {
          setState(() => _busy = false);
          await _reload();
        }
      }
      return;
    }
    await _confirmAndRevoke();
  }

  Future<void> _confirmAndRevoke() async {
    if (_busy || !_accessOn) return;
    final confirm = widget.confirmRevokeOverride ?? _showRevokeDialog;
    final confirmed = await confirm(context);
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final grant in _caregiverGrants) {
        await _service.revokeGrant(grant);
        PrivacySecurityEngagementAnalytics.caregiverTokenRevoked(
          tokenId: grant.grantId,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _reload();
      }
    }
  }

  Future<bool> _showRevokeDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('caregiver_consent_revoke_dialog'),
        title: const Text(CaregiverConsentCopy.revokeConfirmTitle),
        content: const Text(CaregiverConsentCopy.revokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(CaregiverConsentCopy.revokeCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(CaregiverConsentCopy.revokeCta),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.caregiverMonitoring) {
      return const SizedBox.shrink();
    }

    return PushedScreenShell(
      title: CaregiverConsentCopy.screenTitle,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          key: CaregiverConsentScreen.screenKey,
          padding: EdgeInsets.zero,
          children: [
            const _Banner(),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              key: CaregiverConsentScreen.masterSwitchKey,
              contentPadding: EdgeInsets.zero,
              title: Text(
                CaregiverConsentCopy.masterTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                _accessOn
                    ? CaregiverConsentCopy.statusOn(
                        partyLabels: [
                          for (final grant in _caregiverGrants)
                            grant.displayLabel,
                        ],
                      )
                    : CaregiverConsentCopy.statusOff,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              value: _accessOn,
              onChanged: _busy || _loading ? null : _onMasterChanged,
            ),
            if (!_accessOn) ...[
              const SizedBox(height: AppSpacing.md),
              const CaregiverEntryPoint(),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              CaregiverConsentCopy.sharingOptionsHeading,
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _UnavailableRow(
              rowKey: CaregiverConsentScreen.moodRowKey,
              title: CaregiverConsentCopy.moodTitle,
              body: CaregiverConsentCopy.moodBody,
            ),
            const _UnavailableRow(
              rowKey: CaregiverConsentScreen.alertsRowKey,
              title: CaregiverConsentCopy.alertsTitle,
              body: CaregiverConsentCopy.alertsBody,
            ),
            const _UnavailableRow(
              rowKey: CaregiverConsentScreen.checkInsRowKey,
              title: CaregiverConsentCopy.checkInsTitle,
              body: CaregiverConsentCopy.checkInsBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: CaregiverConsentScreen.revokeKey,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive),
                  minimumSize: const Size(0, 48),
                ),
                onPressed: _busy || _loading || !_accessOn
                    ? null
                    : () => unawaited(_confirmAndRevoke()),
                child: const Text(CaregiverConsentCopy.revokeCta),
              ),
            ),
            if (!_accessOn) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                CaregiverConsentCopy.revokeDisabled,
                style: ArchiveMobileTypography.listSubtitle(context).copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: CaregiverConsentScreen.bannerKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
      ),
      child: Text(
        CaregiverConsentCopy.banner,
        style: ArchiveMobileTypography.listSubtitle(context).copyWith(
          height: 1.45,
        ),
      ),
    );
  }
}

class _UnavailableRow extends StatelessWidget {
  const _UnavailableRow({
    required this.rowKey,
    required this.title,
    required this.body,
  });

  final Key rowKey;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      enabled: false,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: ArchiveMobileTypography.listTitle(context),
      ),
      subtitle: Text(
        body,
        style: ArchiveMobileTypography.listSubtitle(context),
      ),
    );
  }
}

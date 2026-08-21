import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Active caregiver tokens with revoke actions backed by [CaregiverAccessService].
class CaregiverConsentManagerWidget extends StatefulWidget {
  const CaregiverConsentManagerWidget({
    super.key,
    this.accessService,
    this.onRevoked,
    this.confirmRevokeOverride,
  });

  final CaregiverAccessService? accessService;
  final VoidCallback? onRevoked;

  /// When set (tests only), replaces the revoke confirmation dialog.
  @visibleForTesting
  final Future<bool> Function(
    BuildContext context,
    CaregiverActiveGrant grant,
  )? confirmRevokeOverride;

  @override
  State<CaregiverConsentManagerWidget> createState() =>
      _CaregiverConsentManagerWidgetState();
}

class _CaregiverConsentManagerWidgetState
    extends State<CaregiverConsentManagerWidget> {
  List<CaregiverActiveGrant> _grants = const [];
  bool _loading = true;
  String? _revokingTokenId;

  CaregiverAccessService get _accessService {
    if (widget.accessService != null) return widget.accessService!;
    final prefs = AppServices.instance.prefs;
    return CaregiverAccessService(
      auditStore: CaregiverAuditStore(prefs),
      modeStore: CaregiverModeStore(prefs),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!AppServices.isInitialized && widget.accessService == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final overview = await _accessService.loadOverview();
    if (!mounted) return;
    setState(() {
      _grants = overview.activeGrants;
      _loading = false;
    });
  }

  Future<void> _revoke(CaregiverActiveGrant grant) async {
    PrivacySecurityEngagementAnalytics.caregiverTokenRevoked(
      tokenId: grant.tokenId,
    );
    setState(() => _revokingTokenId = grant.tokenId);
    try {
      if (CaregiverModeController.isConfigured) {
        await CaregiverModeController.instance.revokeGrant(grant.tokenId);
      } else {
        await _revokeWithoutController(grant.tokenId);
      }
      widget.onRevoked?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(PrivacySecurityControlCenterCopy.revokeSuccessSnack),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingTokenId = null);
      await _reload();
    }
  }

  Future<void> _revokeWithoutController(String tokenId) async {
    await ConsentVerificationService().revokeToken(tokenId);
    final prefs = AppServices.instance.prefs;
    final auditStore = CaregiverAuditStore(prefs);
    await auditStore.append(
      sessionId: 'none',
      action: CaregiverAuditAction.consentRevoked,
      resourceType: 'consent_token',
      resourceId: tokenId,
    );
    final modeStore = CaregiverModeStore(prefs);
    final stored = await modeStore.readStoredToken();
    if (stored?.tokenId == tokenId) {
      await modeStore.clearMonitoringState();
    }
  }

  Future<void> _confirmAndRevokeBody(CaregiverActiveGrant grant) async {
    final confirmRevoke = widget.confirmRevokeOverride ?? _showRevokeDialog;
    final confirmed = await confirmRevoke(context, grant);
    if (confirmed == true) {
      await _revoke(grant);
    }
  }

  Future<bool> _showRevokeDialog(
    BuildContext context,
    CaregiverActiveGrant grant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        key: Key('caregiver_revoke_confirm_dialog_${grant.tokenId}'),
        title: const Text(PrivacySecurityControlCenterCopy.revokeAccessCta),
        content: const Text(
          PrivacySecurityControlCenterCopy.revokeAccessConfirmBody,
        ),
        actions: [
          TextButton(
            key: Key('caregiver_revoke_cancel_${grant.tokenId}'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('caregiver_revoke_confirm_${grant.tokenId}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(PrivacySecurityControlCenterCopy.revokeAccessCta),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      key: const Key('caregiver_consent_manager'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PrivacySecurityControlCenterCopy.caregiverSectionSubtitle,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_grants.isEmpty)
          Text(
            CaregiverCopy.noActiveAccessMessage,
            key: const Key('caregiver_consent_manager_empty'),
            style: ArchiveMobileTypography.listSubtitle(context),
          )
        else
          ..._grants.map((grant) => _GrantCard(
                grant: grant,
                isRevoking: _revokingTokenId == grant.tokenId,
                onRevokePressed: () => unawaited(_confirmAndRevokeBody(grant)),
              )),
      ],
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({
    required this.grant,
    required this.onRevokePressed,
    required this.isRevoking,
  });

  final CaregiverActiveGrant grant;
  final VoidCallback onRevokePressed;
  final bool isRevoking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final grantedLabel = dateFormat.format(grant.grantedAt.toLocal());

    return Container(
      key: Key('caregiver_consent_grant_${grant.tokenId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            grant.caregiverId,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${CaregiverCopy.grantedAtLabel}: $grantedLabel'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: Key('caregiver_revoke_access_${grant.tokenId}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            onPressed: isRevoking ? null : onRevokePressed,
            child: isRevoking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(PrivacySecurityControlCenterCopy.revokeAccessCta),
          ),
        ],
      ),
    );
  }
}

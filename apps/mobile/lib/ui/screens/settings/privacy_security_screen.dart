import 'dart:async';

import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/access_revocation_audit_log_view.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/biometric_security_tile.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/caregiver_consent_manager_widget.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/encryption_status_card.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/privacy_pillar_expansion_section.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// Privacy & Security Control Center — encryption, biometric gate, caregiver
/// consent, and audit history.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({
    super.key,
    this.accessService,
    this.confirmRevokeOverride,
  });

  final CaregiverAccessService? accessService;

  /// Test-only hook to drive revoke confirmation without platform dialogs.
  @visibleForTesting
  final Future<bool> Function(
    BuildContext context,
    CaregiverActiveGrant grant,
  )? confirmRevokeOverride;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  List<AuditLogEntry> _auditLog = const [];
  int _refreshTick = 0;

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
    unawaited(_reloadAuditLog());
  }

  Future<void> _reloadAuditLog() async {
    if (!AppServices.isInitialized && widget.accessService == null) return;
    final overview = await _accessService.loadOverview();
    if (!mounted) return;
    setState(() => _auditLog = overview.accessLog);
  }

  void _onStateChanged() {
    setState(() => _refreshTick++);
    unawaited(_reloadAuditLog());
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: PrivacySecurityControlCenterCopy.screenTitle,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          key: const Key('privacy_security_control_center_screen'),
          padding: EdgeInsets.zero,
          children: [
            PrivacyPillarExpansionSection(
              cardId: PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
              title: PrivacySecurityControlCenterCopy.pillar3Heading,
              explanationTitle:
                  PrivacySecurityControlCenterCopy.pillar3ExplanationTitle,
              explanationBody:
                  PrivacySecurityControlCenterCopy.pillar3ExplanationBody,
              children: [
                const EncryptionStatusCard(),
                const SizedBox(height: AppSpacing.md),
                BiometricSecurityTile(
                  key: ValueKey('biometric_tile_$_refreshTick'),
                  onChanged: _onStateChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrivacyPillarExpansionSection(
              cardId: PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId,
              title: PrivacySecurityControlCenterCopy.pillar4Heading,
              explanationTitle:
                  PrivacySecurityControlCenterCopy.pillar4ExplanationTitle,
              explanationBody:
                  PrivacySecurityControlCenterCopy.pillar4ExplanationBody,
              children: [
                CaregiverConsentManagerWidget(
                  key: ValueKey('caregiver_manager_$_refreshTick'),
                  accessService: widget.accessService,
                  confirmRevokeOverride: widget.confirmRevokeOverride,
                  onRevoked: _onStateChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AccessRevocationAuditLogView(entries: _auditLog),
          ],
        ),
      ),
    );
  }
}

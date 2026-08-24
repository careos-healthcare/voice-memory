import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_audit_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/features/settings/ui/encryption_baseline_badge.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_section.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/access_revocation_audit_log_view.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/biometric_security_tile.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/encryption_status_card.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/privacy_pillar_expansion_section.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Privacy & Security Control Center — encryption, biometric gate, caregiver
/// access entry point, and audit history.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, this.accessService});

  final CaregiverAccessService? accessService;

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
            const OnDeviceArchitectureSection(),
            // Footnote under the on-device statement, above the live
            // `EncryptionStatusCard`: design baseline first, then what this
            // build actually reports.
            const EncryptionBaselineBadge(),
            const SizedBox(height: AppSpacing.lg),
            // This screen is the only surface that reports the encryption state
            // this build actually runs with, so the card is open on arrival
            // rather than a tap away. The section keeps its collapse affordance
            // and its "why am I seeing this" explanation.
            PrivacyPillarExpansionSection(
              cardId: PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
              title: PrivacySecurityControlCenterCopy.pillar3Heading,
              initiallyExpanded: true,
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
            // Grants are managed on `/caregiver-access`, which is canonical.
            // Same ship gate as the Settings entry: no link until the
            // capability is on, though the route stays registered so a stale
            // grant remains revocable by deep link.
            //
            // The pillar wrapper is what makes the caregiver claim checkable
            // on the same terms as the encryption one: heading, "why am I
            // seeing this" explanation, and the `pillar_4_caregiver` card id
            // the analytics already declared. Copy and analytics id both
            // existed and neither had a reader, so the section rendered a bare
            // link while the strings describing what a grant is sat unread.
            // Open on arrival so the link is reachable without a tap.
            if (V1CapabilityRegistry.caregiverMonitoring) ...[
              PrivacyPillarExpansionSection(
                cardId: PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId,
                title: PrivacySecurityControlCenterCopy.pillar4Heading,
                initiallyExpanded: true,
                explanationTitle:
                    PrivacySecurityControlCenterCopy.pillar4ExplanationTitle,
                explanationBody:
                    PrivacySecurityControlCenterCopy.pillar4ExplanationBody,
                children: [
                  Text(
                    PrivacySecurityControlCenterCopy.caregiverSectionSubtitle,
                    key: const Key('privacy_security_caregiver_section_subtitle'),
                    style: ArchiveMobileTypography.listSubtitle(context),
                  ),
                  ListTile(
                    key: const Key('privacy_security_caregiver_access_link'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(CaregiverAccessCopy.settingsTitle),
                    subtitle: const Text(CaregiverAccessCopy.settingsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/caregiver-access'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AccessRevocationAuditLogView(entries: _auditLog),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/views/caregiver_active_grant_tile.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_read_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Read-only caregiver dashboard — evidence trail, summaries, and alerts.
class CaregiverDashboardView extends StatefulWidget {
  const CaregiverDashboardView({
    super.key,
    this.readService,
    this.modeController,
  });

  final CaregiverReadService? readService;
  final CaregiverModeController? modeController;

  @override
  State<CaregiverDashboardView> createState() => _CaregiverDashboardViewState();
}

class _CaregiverDashboardViewState extends State<CaregiverDashboardView> {
  CaregiverDashboardSnapshot? _snapshot;
  CaregiverAccessOverview? _accessOverview;
  bool _loading = true;
  String? _error;
  String? _revokingTokenId;

  CaregiverModeController get _controller =>
      widget.modeController ?? CaregiverModeController.instance;

  CaregiverReadService get _readService =>
      widget.readService ??
      CaregiverReadService(
        journalStore: AppServices.instance.journalStore,
        modeController: _controller,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller.initialize();
    if (!_controller.hasValidSession) {
      setState(() {
        _loading = false;
        _error = CaregiverCopy.noSessionMessage;
      });
      return;
    }
    final snapshot = await _readService.loadDashboardSnapshot();
    final accessOverview = await _controller.accessService.loadOverview();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _snapshot = snapshot;
      _accessOverview = accessOverview;
      _error = snapshot == null ? CaregiverCopy.noSessionMessage : null;
    });
  }

  Future<void> _revokeGrant(CaregiverActiveGrant grant) async {
    setState(() => _revokingTokenId = grant.tokenId);
    await _controller.revokeGrant(grant.tokenId);
    if (!mounted) return;
    setState(() => _revokingTokenId = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CaregiverCopy.dashboardTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      actions: [
        TextButton(
          onPressed: () => unawaited(_exitMonitoring(context)),
          child: const Text(CaregiverCopy.switchToSelfCta),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _messageBody(_error!)
              : _dashboardBody(context, _snapshot!, _accessOverview!),
    );
  }

  Widget _messageBody(String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, style: ArchiveMobileTypography.explanationBody(context)),
    );
  }

  Widget _dashboardBody(
    BuildContext context,
    CaregiverDashboardSnapshot snapshot,
    CaregiverAccessOverview accessOverview,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                CaregiverCopy.readOnlyBadge,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          CaregiverCopy.dashboardSubtitle,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        _section(
          context,
          title: CaregiverCopy.activeAccessLabel,
          child: accessOverview.activeGrants.isEmpty
              ? const Text(CaregiverCopy.noActiveAccessMessage)
              : Column(
                  children: accessOverview.activeGrants
                      .map(
                        (grant) => CaregiverActiveGrantTile(
                          grant: grant,
                          isRevoking: _revokingTokenId == grant.tokenId,
                          onRevoke: () => unawaited(_revokeGrant(grant)),
                        ),
                      )
                      .toList(),
                ),
        ),
        _section(
          context,
          title: CaregiverCopy.accessLogLabel,
          child: accessOverview.accessLog.isEmpty
              ? const Text(CaregiverCopy.emptyAccessLogMessage)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: accessOverview.accessLog
                      .take(20)
                      .map((entry) => _accessLogRow(context, entry))
                      .toList(),
                ),
        ),
        _section(
          context,
          title: CaregiverCopy.evidenceTrailLabel,
          child: snapshot.evidenceCount == 0
              ? const Text(CaregiverCopy.emptyEvidenceMessage)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${snapshot.evidenceCount} preserved moments'),
                    const SizedBox(height: AppSpacing.sm),
                    ...snapshot.recentEvidenceLabels.map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text('• $label'),
                      ),
                    ),
                  ],
                ),
        ),
        _section(
          context,
          title: CaregiverCopy.timelineSummariesLabel,
          child: snapshot.timelineSummaries.isEmpty
              ? const Text('No timeline summaries yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.timelineSummaries
                      .map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text('• $line'),
                          ))
                      .toList(),
                ),
        ),
        _section(
          context,
          title: CaregiverCopy.thresholdAlertsLabel,
          child: snapshot.priorityAlerts.isEmpty
              ? const Text('No priority alerts right now.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: snapshot.priorityAlerts
                      .map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text('• $alert'),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          CaregiverCopy.auditNotice,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      ],
    );
  }

  Widget _accessLogRow(BuildContext context, AuditLogEntry entry) {
    final timestamp = entry.timestamp.toLocal().toIso8601String().split('.').first;
    final resource = entry.resourceId == null || entry.resourceId!.isEmpty
        ? entry.resourceType
        : '${entry.resourceType} (${entry.resourceId})';

    return Padding(
      key: Key('caregiver_access_log_${entry.entryId}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text('• $timestamp — ${entry.action.wireValue} — $resource'),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.sectionTitle(context)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Future<void> _exitMonitoring(BuildContext context) async {
    await _controller.switchToSelfReflection();
    if (!context.mounted) return;
    context.go(RouteCatalog.recordHome);
  }
}

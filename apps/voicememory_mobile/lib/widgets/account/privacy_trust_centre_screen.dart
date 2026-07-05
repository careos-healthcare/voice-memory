import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_history/archive_history_engine.dart';
import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_activation/beta_activation_summary_copy.dart';
import '../../features/beta_feedback/beta_feedback_engine.dart';
import '../../features/early_archive/early_first_signal_engine.dart';
import '../../features/early_archive/private_archive_report_engine.dart';
import '../../features/local_backup/local_backup_copy.dart';
import '../../features/local_backup/local_backup_restore_service.dart';
import '../../features/privacy_trust/privacy_trust_copy.dart';
import '../../features/repeat_return_check/repeat_return_check_store.dart';
import '../../security/local_privacy_data_controls.dart';
import '../../security/privacy_data_controls_copy.dart';
import '../../services/app_services.dart';
import '../../billing/archive_entitlement_reader.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/account/beta_activation_summary_sheet.dart';
import '../../widgets/account/beta_feedback_sheet.dart';
import '../../widgets/account/local_backup_restore_sheet.dart';
import '../../widgets/archive_history/archive_history_sheet.dart';
import '../../widgets/pushed_screen_shell.dart';
import '../../widgets/private_report/private_report_sheet.dart';
import '../../widgets/settings/privacy_data_controls_dialogs.dart';

/// Privacy & Trust Centre — what is stored, what stays private, and controls.
class PrivacyTrustCentreScreen extends StatefulWidget {
  const PrivacyTrustCentreScreen({
    super.key,
    this.controls,
    this.entitlementReader,
  });

  final LocalPrivacyDataControls? controls;
  final ArchiveEntitlementReader? entitlementReader;

  @override
  State<PrivacyTrustCentreScreen> createState() =>
      _PrivacyTrustCentreScreenState();
}

class _PrivacyTrustCentreScreenState extends State<PrivacyTrustCentreScreen> {
  bool _deleteBusy = false;
  bool _exportBusy = false;
  bool _restoreBusy = false;
  int _entryCount = 0;
  bool _loaded = false;

  LocalPrivacyDataControls get _controls =>
      widget.controls ?? LocalPrivacyDataControls.instance();

  LocalBackupRestoreService get _backupService => LocalBackupRestoreService(
        controls: widget.controls,
      );

  @override
  void initState() {
    super.initState();
    _loadEntryCount();
  }

  Future<void> _loadEntryCount() async {
    if (!AppServices.isInitialized) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _entryCount = const BetaFeedbackEngine().realEntryCount(entries);
      _loaded = true;
    });
  }

  Future<void> _openArchiveHistory() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    final content = ArchiveHistoryEngine.build(entries: entries);
    if (!mounted) return;
    await ArchiveHistorySheet.show(
      context,
      content: content,
      entryCount: entries.length,
    );
  }

  Future<void> _deleteArchive() async {
    if (_deleteBusy) return;
    final confirmed = await showClearLocalArchiveDialog(context);
    if (!confirmed || !mounted) return;

    setState(() => _deleteBusy = true);
    try {
      await _controls.clearLocalArchive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(PrivacyTrustCopy.deleteArchiveDone)),
      );
      await _loadEntryCount();
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  Future<void> _copyPrivateReport() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    final viewingConfirmed =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final report = PrivateArchiveReportEngine.build(
      entries: entries,
      returnChecks: RepeatReturnCheckStore.cached,
      viewingConfirmedRepeatOrTimeline: viewingConfirmed,
    );
    if (!mounted) return;
    if (report == null || !report.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(PrivacyTrustCopy.notEnoughReportEvidence)),
      );
      return;
    }

    final reader =
        widget.entitlementReader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    if (!mounted) return;

    await PrivateReportSheet.show(
      context,
      report: report,
      entryCount: entries.length,
      surface: 'privacy_trust_centre',
      isPro: isPro,
    );
  }

  void _sendBetaFeedback() {
    BetaFeedbackSheet.show(
      context,
      source: 'privacy_trust_centre',
      entryCount: _entryCount,
    );
  }

  void _openBetaProgressSummary() {
    BetaActivationSummarySheet.show(context);
  }

  Future<void> _exportLocalBackup() async {
    if (_exportBusy || !_loaded) return;
    setState(() => _exportBusy = true);
    try {
      await runExportLocalBackupFlow(
        context,
        service: _backupService,
        source: 'privacy_trust_centre',
        onComplete: _loadEntryCount,
      );
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _restoreLocalBackup() async {
    if (_restoreBusy || !_loaded) return;
    setState(() => _restoreBusy = true);
    try {
      await runRestoreLocalBackupFlowWithConfirmation(
        context,
        service: _backupService,
        source: 'privacy_trust_centre',
        pickBackupFile: () => _backupService.pickBackupFileContent(),
        onComplete: _loadEntryCount,
      );
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final showBetaSummary = ArchiveBetaMissionGate.isEnabled;

    return PushedScreenShell(
      title: PrivacyTrustCopy.title,
      fallbackRoute: '/settings',
      body: SingleChildScrollView(
        key: const Key('privacy_trust_centre_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoSection(
              context,
              key: const Key('privacy_trust_section_what_stores'),
              heading: PrivacyTrustCopy.whatStoresHeading,
              body: PrivacyTrustCopy.whatStoresBody,
              bodyStyle: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            _infoSection(
              context,
              key: const Key('privacy_trust_section_not_included'),
              heading: PrivacyTrustCopy.whatNotIncludedHeading,
              body: PrivacyTrustCopy.whatNotIncludedBody,
              bodyStyle: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            _infoSection(
              context,
              key: const Key('privacy_trust_section_stays_private'),
              heading: PrivacyTrustCopy.whatStaysPrivateHeading,
              body: PrivacyTrustCopy.whatStaysPrivateBody,
              bodyStyle: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              PrivacyTrustCopy.yourControlsHeading,
              key: const Key('privacy_trust_controls_heading'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            _controlTile(
              key: const Key('privacy_trust_control_correct_transcript'),
              title: PrivacyTrustCopy.correctTranscriptControl,
              onTap: _loaded ? _openArchiveHistory : null,
            ),
            _controlTile(
              key: const Key('privacy_trust_control_delete_archive'),
              title: PrivacyTrustCopy.deleteArchiveControl,
              destructive: true,
              busy: _deleteBusy,
              onTap: _deleteBusy ? null : _deleteArchive,
            ),
            _controlTile(
              key: const Key('privacy_trust_control_copy_private_report'),
              title: PrivacyTrustCopy.copyPrivateReportControl,
              onTap: _loaded ? _copyPrivateReport : null,
            ),
            _controlTile(
              key: const Key('privacy_trust_control_export_backup'),
              title: LocalBackupCopy.exportControl,
              busy: _exportBusy,
              onTap: _exportBusy || !_loaded ? null : _exportLocalBackup,
            ),
            _controlTile(
              key: const Key('privacy_trust_control_restore_backup'),
              title: LocalBackupCopy.restoreControl,
              busy: _restoreBusy,
              onTap: _restoreBusy || !_loaded ? null : _restoreLocalBackup,
            ),
            _controlTile(
              key: const Key('privacy_trust_control_beta_feedback'),
              title: PrivacyTrustCopy.sendBetaFeedbackControl,
              onTap: _sendBetaFeedback,
            ),
            const SizedBox(height: AppSpacing.lg),
            _infoSection(
              context,
              key: const Key('privacy_trust_section_beta_measurement'),
              heading: PrivacyTrustCopy.betaMeasurementHeading,
              body: PrivacyTrustCopy.betaMeasurementBody,
              bodyStyle: bodyStyle,
            ),
            if (showBetaSummary) ...[
              const SizedBox(height: AppSpacing.sm),
              _controlTile(
                key: const Key('privacy_trust_control_beta_summary'),
                title: BetaActivationSummaryCopy.openLink,
                onTap: _openBetaProgressSummary,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('privacy_trust_full_privacy_policy'),
              onPressed: () => context.push('/privacy'),
              child: Text(PrivacyDataControlsCopy.dataStaysOnDeviceTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(
    BuildContext context, {
    required Key key,
    required String heading,
    required String body,
    required TextStyle bodyStyle,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(body, style: bodyStyle),
      ],
    );
  }

  Widget _controlTile({
    required Key key,
    required String title,
    required VoidCallback? onTap,
    bool destructive = false,
    bool busy = false,
  }) {
    return ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: ArchiveMobileTypography.listTitle(context).copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

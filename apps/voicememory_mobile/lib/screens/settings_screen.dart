import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../billing/restore_purchases_feedback.dart';
import '../billing/restore_purchases_flow.dart';
import '../billing/archive_entitlement_reader.dart';
import '../config/developer_settings_gate.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../features/archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import '../features/archive_backup_bridge/archive_backup_bridge_engine.dart';
import '../features/archive_backup_bridge/archive_backup_bridge_model.dart';
import '../features/beta/archive_beta_mission_gate.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import '../features/beta_test_script/beta_test_script_copy.dart';
import '../features/pro_evidence_value/pro_evidence_value_engine.dart';
import '../models/journal_entry.dart';
import '../features/help/help_reviewer_guide_copy.dart';
import '../features/privacy_trust/privacy_trust_copy.dart';
import '../features/pro/pro_value_preview_copy.dart';
import '../features/support/support_feedback_copy.dart';
import '../features/support/testflight_feedback_copy.dart';
import '../features/archive_packs/archive_pack.dart';
import '../features/action_items/archive_action_item.dart';
import '../features/fact_ledger/archive_fact.dart';
import '../features/collections/archive_collection.dart';
import '../features/archive_proof/visible_archive_proof_copy.dart';
import '../features/pins/pinned_evidence_store.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../product/consumer_ui_copy.dart';
import '../security/security_settings_copy.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/memory/memory_scope_settings_section.dart';
import '../widgets/settings/privacy_data_controls_section.dart';
import '../features/revenue_metrics/revenue_readiness_engine.dart';
import '../widgets/debug/revenue_readiness_card.dart';
import '../widgets/beta/beta_feedback_intelligence_card.dart';
import '../widgets/pro/archive_backup_bridge_card.dart';
import '../widgets/pushed_screen_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _restoreBusy = false;
  RestorePurchasesFlow? _restoreFlow;
  bool _remindersEnabled = false;
  bool _remindersBusy = false;
  List<JournalEntry> _journalEntries = const [];
  bool _isPro = false;
  @override
  void initState() {
    super.initState();
    unawaited(BetaFeedbackIntelligenceStore.ensureLoaded());
    unawaited(ArchiveBackupBridgeDismissStore.ensureLoaded());
    unawaited(_loadJournalEntries());
    unawaited(_loadIsPro());
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    CheckInReminderService.remindersEnabled().then((value) {
      if (mounted) setState(() => _remindersEnabled = value);
    });
  }

  String get _reminderStateLabel {
    if (!_remindersEnabled) return ConsumerUiCopy.reminderStateOff;
    if (!CheckInReminderService.pluginAvailable) {
      return ConsumerUiCopy.reminderStatePermissionNeeded;
    }
    return ConsumerUiCopy.reminderStateOn;
  }

  String get _reminderBody {
    if (!_remindersEnabled) return ConsumerUiCopy.reminderSettingsBodyOff;
    if (!CheckInReminderService.pluginAvailable) {
      return ConsumerUiCopy.reminderSettingsBodyPermissionNeeded;
    }
    return ConsumerUiCopy.reminderSettingsBodyOn;
  }

  Future<void> _toggleReminders(bool enable) async {
    if (_remindersBusy) return;
    setState(() => _remindersBusy = true);
    try {
      if (!enable) {
        await CheckInReminderService.setRemindersEnabled(false);
        if (mounted) setState(() => _remindersEnabled = false);
        return;
      }
      await CheckInReminderService.setRemindersEnabled(true);
      final active = await TomorrowCheckInCoordinator.loadActive();
      if (active != null) {
        await CheckInReminderService.scheduleTomorrowCheckInReminder(active);
      } else {
        await CheckInReminderService.requestPermissionOnly();
      }
      if (mounted) setState(() => _remindersEnabled = true);
    } finally {
      if (mounted) setState(() => _remindersBusy = false);
    }
  }

  void _openTestingArchiveMeGuide() {
    context.push('/testing-archiveme');
  }

  Future<void> _loadJournalEntries() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() => _journalEntries = entries);
  }

  Future<void> _loadIsPro() async {
    final isPro = await ArchiveEntitlementReader.forAccessCheck().isPro;
    if (!mounted) return;
    setState(() => _isPro = isPro);
  }

  Future<void> _dismissArchiveBackupBridge() async {
    await ArchiveBackupBridgeDismissStore.dismiss();
    if (mounted) setState(() {});
  }

  Future<void> _restorePurchases() async {
    final flow = _restoreFlow ??= RestorePurchasesFlow(
      billing: AppServices.instance.billing,
    );
    if (flow.isBusy || _restoreBusy) return;

    setState(() => _restoreBusy = true);
    try {
      final result = await flow.restore();
      if (!mounted || result.outcome == RestorePurchasesOutcome.skippedBusy) {
        return;
      }
      RestorePurchasesFeedback.showSnackBar(context, result);
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _packageInfo == null
        ? '…'
        : '${_packageInfo!.version} (${_packageInfo!.buildNumber})';
    final showSettingsBetaFeedbackCard = ArchiveBetaMissionGate.isEnabled &&
        BetaFeedbackIntelligenceEngine.shouldShowCard(
          BetaFeedbackIntelligenceEngine.buildContext(
            surface: BetaFeedbackIntelligenceSurface.settingsBeta,
            entryCount: _journalEntries.length,
            entries: _journalEntries,
            isZeroEntryState: _journalEntries.isEmpty,
            firstProofPayoffVisible:
                BetaFeedbackIntelligenceStore.cached.hasReachedFirstProof,
          ),
        );
    final settingsFirstProofReached =
        BetaFeedbackIntelligenceStore.cached.hasReachedFirstProof ||
            ProEvidenceValueEngine.firstProofPayoffSeenForEntries(
              _journalEntries,
            );
    final archiveBackupBridgeContext =
        ArchiveBackupBridgeEngine.buildContext(
      surface: ArchiveBackupBridgeSurface.settings,
      entryCount: _journalEntries.length,
      isPro: _isPro,
      dismissed: ArchiveBackupBridgeDismissStore.isDismissed(),
      entries: _journalEntries,
      isZeroEntryState: _journalEntries.isEmpty,
    );
    final showArchiveBackupBridgeOnSettings =
        ArchiveBackupBridgeEngine.shouldShowCard(archiveBackupBridgeContext);

    return PushedScreenShell(
      title: ConsumerUiCopy.settings,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              key: const Key('settings_privacy_trust_centre_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                PrivacyTrustCopy.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/privacy-trust-centre'),
            ),
            _tile(
              ConsumerUiCopy.privacy,
              onTap: () => context.push('/privacy'),
            ),
            _tile(
              ConsumerUiCopy.termsOfUse,
              onTap: () => context.push('/terms'),
            ),
            ListTile(
              key: const Key('settings_help_reviewer_guide_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                HelpReviewerGuideCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                HelpReviewerGuideCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/help-reviewer-guide'),
            ),
            ListTile(
              key: const Key('settings_support_feedback_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                SupportFeedbackCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                SupportFeedbackCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/support-feedback'),
            ),
            if (ArchiveBetaMissionGate.isEnabled)
              ListTile(
                key: const Key('settings_testflight_feedback_tile'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  BetaTestScriptCopy.settingsTileTitle,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                subtitle: Text(
                  BetaTestScriptCopy.settingsTileBody,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openTestingArchiveMeGuide,
              ),
            if (showSettingsBetaFeedbackCard) ...[
              const SizedBox(height: AppSpacing.sm),
              BetaFeedbackIntelligenceCard(
                surface: BetaFeedbackIntelligenceSurface.settingsBeta,
                entryCount: _journalEntries.length,
                reachedFirstProof: settingsFirstProofReached,
                compact: true,
                onSubmitted: () {
                  if (mounted) setState(() {});
                },
              ),
            ],
            if (ArchiveBetaMissionGate.isEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              RevenueReadinessCard(
                dashboard: RevenueReadinessEngine.build(),
              ),
            ],
            if (showArchiveBackupBridgeOnSettings) ...[
              const SizedBox(height: AppSpacing.sm),
              ArchiveBackupBridgeCard(
                contextData: archiveBackupBridgeContext,
                compact: true,
                onSeePro: _isPro ? null : () => context.push('/subscription'),
                onDismiss: () => unawaited(_dismissArchiveBackupBridge()),
              ),
            ],
            ListTile(
              key: const Key('settings_pro_value_preview_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ProValuePreviewCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ProValuePreviewCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pro-preview'),
            ),
            _tile(
              ConsumerUiCopy.restorePurchases,
              onTap: _restoreBusy ? null : _restorePurchases,
            ),
            const PrivacyDataControlsSection(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                ConsumerUiCopy.reminderSettingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                '$_reminderStateLabel · $_reminderBody',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              value: _remindersEnabled,
              onChanged: _remindersBusy ? null : _toggleReminders,
            ),
            // Memory: when ArchiveMe may connect entries. Persistent and
            // user-only — "Memory off" stays off until changed here.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: MemoryScopeSettingsSection(),
            ),
            ListTile(
              key: const Key('settings_insight_quality_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                VisibleArchiveProofCopy.insightQualitySettingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                VisibleArchiveProofCopy.insightQualitySettingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/insight-quality'),
            ),
            ListTile(
              key: const Key('settings_security_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                SecuritySettingsCopy.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                SecuritySettingsCopy.subtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/security'),
            ),
            ListTile(
              key: const Key('settings_pinned_evidence_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                PinnedEvidenceCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                PinnedEvidenceCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pinned-evidence'),
            ),
            ListTile(
              key: const Key('settings_archive_packs_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ArchivePacksCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ArchivePacksCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/archive-packs'),
            ),
            ListTile(
              key: const Key('settings_details_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                FactLedgerCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                FactLedgerCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/details'),
            ),
            ListTile(
              key: const Key('settings_action_items_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ActionItemsCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ActionItemsCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/action-items'),
            ),
            ListTile(
              key: const Key('settings_collections_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ArchiveCollectionsCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ArchiveCollectionsCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/collections'),
            ),
            _tile(
              ConsumerUiCopy.deleteAccount,
              onTap: () => context.push('/delete-account'),
              destructive: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              ConsumerUiCopy.appVersion,
              style: ArchiveMobileTypography.cardLabel(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              versionLabel,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            if (DeveloperSettingsGate.canShowDeveloperSettings) ...[
              const Divider(height: 28),
              _tile(
                'Developer diagnostics',
                onTap: () => context.push('/developer-diagnostics'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    String title, {
    VoidCallback? onTap,
    Widget? trailing,
    bool destructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: ArchiveMobileTypography.listTitle(context).copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

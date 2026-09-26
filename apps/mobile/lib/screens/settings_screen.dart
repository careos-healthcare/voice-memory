import 'dart:async';

import 'package:archiveme_mobile/features/memory/what_thoughtprint_remembers_screen.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/features/onboarding/cloud_consent.dart';
import 'package:archiveme_mobile/features/onboarding/cloud_consent_modal.dart';
import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/production_navigation.dart';
import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/core/notifications/journal_reminder_settings_section.dart';
import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/action_items/archive_action_item.dart';
import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_actions.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/settings/speech_language_settings.dart';
import 'package:archiveme_mobile/features/settings/services/notification_service.dart';
import 'package:archiveme_mobile/features/settings/views/debug_menu_view.dart';
import 'package:archiveme_mobile/features/settings/views/settings_view.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/core/notifications/journal_notification_plan.dart';
import 'package:archiveme_mobile/features/export/archive_transfer_screen.dart';
import 'package:archiveme_mobile/features/export/services/auto_backup_service.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/features/beta_test_script/beta_test_script_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_entry_point.dart';
import 'package:archiveme_mobile/features/collections/archive_collection.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/apple_health_prompt.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:archiveme_mobile/features/insights/views/knowledge_manager_view.dart';
import 'package:archiveme_mobile/features/help/help_reviewer_guide_copy.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_copy.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_audit_service.dart';
import 'package:archiveme_mobile/widgets/pins/pinned_evidence_store.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_readiness_engine.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/settings/ui/trust_status_footer.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/security/security_settings_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_palette.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/account/account_privacy_controls_section.dart';
import 'package:archiveme_mobile/widgets/beta/beta_conversion_diagnosis_card.dart';
import 'package:archiveme_mobile/widgets/beta/beta_feedback_intelligence_card.dart';
import 'package:archiveme_mobile/widgets/beta/testflight_metrics_dashboard_card.dart';
import 'package:archiveme_mobile/widgets/debug/revenue_readiness_card.dart';
import 'package:archiveme_mobile/widgets/memory/memory_scope_settings_section.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:archiveme_mobile/widgets/settings/app_review_access_settings_section.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_data_controls_section.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_security_trust_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:archiveme_mobile/features/settings/ui/crisis_resources_copy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _remindersEnabled = false;
  bool _remindersBusy = false;
  bool _onDeviceProcessing = OnDeviceProcessingStore.defaultEnabled;
  bool _onDeviceBusy = false;
  bool _cloudSyncEnabled = false;
  bool _healthMoodSyncEnabled = false;
  bool _healthMoodWriteEnabled = false;
  List<JournalEntry> _journalEntries = const [];
  final GlobalKey _onDeviceToggleKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    unawaited(BetaFeedbackIntelligenceStore.ensureLoaded());
    unawaited(_loadJournalEntries());
    unawaited(_loadCloudSync());
    unawaited(
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _packageInfo = info);
      }),
    );
    if (V1CapabilityRegistry.notifications) {
      unawaited(
        CheckInReminderService.remindersEnabled().then((value) {
          if (mounted) setState(() => _remindersEnabled = value);
        }),
      );
    }
    unawaited(
      OnDeviceProcessingStore.ensureLoaded().then((_) {
        if (mounted) {
          setState(() => _onDeviceProcessing = OnDeviceProcessingStore.enabled);
        }
      }),
    );
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

  void _openTestingThoughtprintGuide() {
    if (!ArchiveBetaMissionGate.isEnabled) return;
    unawaited(context.push('/testing-archiveme'));
  }

  Future<void> _toggleOnDeviceProcessing(bool enable) async {
    if (_onDeviceBusy) return;
    setState(() => _onDeviceBusy = true);
    try {
      await OnDeviceProcessingStore.setEnabled(enable);
      if (mounted) setState(() => _onDeviceProcessing = enable);
    } finally {
      if (mounted) setState(() => _onDeviceBusy = false);
    }
  }

  void _scrollToOnDeviceToggle() {
    final context = _onDeviceToggleKey.currentContext;
    if (context == null) return;
    unawaited(
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      ),
    );
  }

  Future<void> _loadCloudSync() async {
    if (!AppServices.isInitialized) return;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    if (!mounted) return;
    setState(() {
      _cloudSyncEnabled = preferences.isCloudSyncEnabled;
      _healthMoodSyncEnabled = preferences.isHealthMoodSyncEnabled;
      _healthMoodWriteEnabled = preferences.isHealthMoodWriteEnabled;
    });
  }

  Future<void> _setCloudSync(bool enabled) async {
    if (enabled) {
      await enableCloudWithProgress(context);
    } else {
      await CloudConsent().disable();
    }
    if (mounted) setState(() => _cloudSyncEnabled = enabled);
  }

  Future<bool> _deleteCloudCopy() async {
    final result = await AppServices.instance.httpTransport.delete(
      CloudSyncService.clearPath,
    );
    return result.when(
      success: (response) {
        final decoded = AppServices.instance.httpTransport.decodeEnvelopeOk(
          response,
        );
        return decoded.when(
          success: (_) => true,
          onFailure: (_) => false,
        );
      },
      onFailure: (_) => false,
    );
  }

  void _showCloudDeleteResult(bool deleted) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Your cloud copy has been deleted.'
              : 'The cloud copy could not be deleted. Try again.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCloudCopy() async {
    if (!AppServices.isInitialized) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('settings_delete_cloud_copy_confirm'),
          title: const Text('Delete my cloud copy?'),
          content: const Text(
            "This deletes the copy of your journal on Thoughtprint's servers. Your journal on this phone is not affected.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('settings_delete_cloud_copy_confirm_accept'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete cloud copy'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _deleteCloudCopy();
    if (deleted) {
      await _setCloudSync(false);
    }
    _showCloudDeleteResult(deleted);
  }

  Future<void> _onCloudSyncChanged(bool enabled) async {
    if (!AppServices.isInitialized) return;
    if (enabled) {
      await _setCloudSync(true);
      return;
    }

    final deleteCloudData = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  'Disable only, or Disable & Delete Cloud Data?',
                  key: Key('settings_cloud_off_prompt'),
                ),
              ),
              ListTile(
                key: const Key('settings_cloud_disable_only'),
                title: const Text('Disable only'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
              ListTile(
                key: const Key('settings_cloud_disable_and_delete'),
                title: const Text('Disable & Delete Cloud Data'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (deleteCloudData == null || !mounted) return;
    if (deleteCloudData) {
      final deleted = await _deleteCloudCopy();
      _showCloudDeleteResult(deleted);
      if (!deleted) return;
    }
    await _setCloudSync(false);
  }

  Future<void> _loadJournalEntries() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() => _journalEntries = entries);
  }

  Future<void> _onAppReviewAccessUnlocked() async {
    await _loadJournalEntries();
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = _packageInfo;
    final versionLabel = packageInfo == null
        ? '…'
        : '${packageInfo.version} (${packageInfo.buildNumber})';
    final showSettingsBetaFeedbackCard =
        ArchiveBetaMissionGate.isEnabled &&
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
        ProEvidenceValueEngine.firstProofPayoffSeenForEntries(_journalEntries);

    return PushedScreenShell(
      title: ConsumerUiCopy.settings,
      fallbackRoute: RouteCatalog.accountHome,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              ConsumerUiCopy.coreIsFreeForever,
              key: const Key('settings_core_is_free'),
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              key: const Key('settings_cloud_sync'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Cloud features',
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                'Off keeps imports and pattern exploration on this device. '
                'On encrypts a backup and allows AI pattern exploration.',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              value: _cloudSyncEnabled,
              onChanged: (value) => unawaited(_onCloudSyncChanged(value)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('settings_delete_cloud_copy'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                onPressed: () => unawaited(_confirmDeleteCloudCopy()),
                child: const Text('Delete my cloud copy'),
              ),
            ),
            ListTile(
              key: const Key('settings_what_i_know'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                KnowledgeManagerView.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                'People, places, and themes from your journal.',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KnowledgeManagerView(),
                  ),
                );
              },
            ),
            if (AppleHealthPlatform.isIos &&
                V1CapabilityRegistry.appleHealth) ...[
              SwitchListTile(
                key: const Key('settings_health_mood_sync'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Sync Apple Health Mood',
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                subtitle: Text(
                  'Reads the State of Mind you logged in Apple Health.',
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                value: _healthMoodSyncEnabled,
                onChanged: (value) async {
                  if (!AppServices.isInitialized) return;
                  if (!value) {
                    await UserPreferences.setHealthMoodSyncEnabled(
                      AppServices.instance.prefs,
                      false,
                    );
                    if (mounted) {
                      setState(() => _healthMoodSyncEnabled = false);
                    }
                    return;
                  }
                  final granted = await confirmThenRequestAppleHealthRead(
                    context,
                  );
                  if (!granted || !mounted) return;
                  await UserPreferences.setHealthMoodSyncEnabled(
                    AppServices.instance.prefs,
                    true,
                  );
                  await StateOfMindReader.forDay(DateTime.now());
                  if (mounted) {
                    setState(() => _healthMoodSyncEnabled = true);
                  }
                },
              ),
              SwitchListTile(
                key: const Key('settings_health_mood_write'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Write journal moods to Apple Health',
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                subtitle: Text(
                  'Saves the mood you choose on a journal entry.',
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                value: _healthMoodWriteEnabled,
                onChanged: (value) async {
                  if (!AppServices.isInitialized) return;
                  if (!value) {
                    await UserPreferences.setHealthMoodWriteEnabled(
                      AppServices.instance.prefs,
                      false,
                    );
                    if (mounted) {
                      setState(() => _healthMoodWriteEnabled = false);
                    }
                    return;
                  }
                  final granted = await confirmThenRequestAppleHealthWrite(
                    context,
                  );
                  if (!granted || !mounted) return;
                  await UserPreferences.setHealthMoodWriteEnabled(
                    AppServices.instance.prefs,
                    true,
                  );
                  if (mounted) {
                    setState(() => _healthMoodWriteEnabled = true);
                  }
                },
              ),
            ],
            const AccountPrivacyControlsSection(),
            const SizedBox(height: AppSpacing.md),
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
              ConsumerUiCopy.termsOfUse,
              onTap: () => context.push('/terms'),
            ),
            if (V1NavigationGuard.isNavRouteVisible('/help-reviewer-guide'))
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
                onTap: _openTestingThoughtprintGuide,
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
              RevenueReadinessCard(dashboard: RevenueReadinessEngine.build()),
              const SizedBox(height: AppSpacing.sm),
              const TestFlightMetricsDashboardCard(),
              const SizedBox(height: AppSpacing.sm),
              const BetaConversionDiagnosisCard(),
            ],
            PrivacySecurityTrustSection(
              onScrollToOnDeviceToggle: _scrollToOnDeviceToggle,
              showOnDeviceLink: V1CapabilityRegistry.localAiPrivacyControls,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Ship gate from docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md:
            // no nav entry until the capability is on. The route itself stays
            // registered so a stale grant remains revocable by deep link.
            if (V1CapabilityRegistry.caregiverMonitoring)
              ListTile(
                key: const Key('settings_caregiver_access_tile'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  CaregiverAccessCopy.settingsTitle,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                subtitle: Text(
                  CaregiverAccessCopy.settingsSubtitle,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/caregiver-access'),
              ),
            const CaregiverEntryPoint(),
            ListTile(
              key: const Key('settings_crisis_resources_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                CrisisResourcesCopy.settingsTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                CrisisResourcesCopy.settingsSubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/crisis-resources'),
            ),
            ListTile(
              key: const Key('settings_privacy_security_control_center_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                PrivacySecurityControlCenterCopy.settingsEntryTitle,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                PrivacySecurityControlCenterCopy.settingsEntrySubtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/privacy-security'),
            ),
            const EncryptedArchiveBackupSettingsTile(),
            AutomaticWeeklyBackupToggle(
              onEnabled: AutoBackupService.runScheduled,
            ),
            SpeechLanguagePreferences(
              readLanguage: () async {
                if (!AppServices.isInitialized) return null;
                return AppServices.instance.prefs.readString(
                  SpeechLanguagePreferences.preferenceKey,
                );
              },
              writeLanguage: (identifier) async {
                if (!AppServices.isInitialized) return;
                await AppServices.instance.prefs.writeString(
                  SpeechLanguagePreferences.preferenceKey,
                  identifier,
                );
                final locale = ConfirmedSpeechLocale.confirmed(identifier);
                if (locale != null) {
                  await SpeechLocaleStore(AppServices.instance.prefs).confirm(
                    locale,
                  );
                }
              },
            ),
            if (V1CapabilityRegistry.e2eeSync)
              E2eeSyncSettings(
                readEnabled: () async {
                  if (!AppServices.isInitialized) return false;
                  return await AppServices.instance.prefs.readBool(
                        E2eeSyncSettings.preferenceKey,
                      ) ??
                      false;
                },
                writeEnabled: (enabled) async {
                  if (!AppServices.isInitialized) return;
                  await AppServices.instance.prefs.writeBool(
                    E2eeSyncSettings.preferenceKey,
                    enabled,
                  );
                },
                storePassphrase: E2eeSyncSettings.storeInVault,
              ),
            JournalReminderPreferences(
              readEnabled: (key) async {
                if (!AppServices.isInitialized) return false;
                return await AppServices.instance.prefs.readBool(key) ?? false;
              },
              writeEnabled: (key, value) async {
                if (!AppServices.isInitialized) return;
                await AppServices.instance.prefs.writeBool(key, value);
                final daily = key == JournalReminderPreferences.dailyKey
                    ? value
                    : await AppServices.instance.prefs.readBool(
                            JournalReminderPreferences.dailyKey,
                          ) ??
                          false;
                final weekly = key == JournalReminderPreferences.weeklyKey
                    ? value
                    : await AppServices.instance.prefs.readBool(
                            JournalReminderPreferences.weeklyKey,
                          ) ??
                          false;
                JournalReminderPlan.scheduled =
                    JournalReminderPlan.fromSettings(
                      now: DateTime.now(),
                      dailyEnabled: daily,
                      weeklyEnabled: weekly,
                    );
                if (weekly) {
                  unawaited(
                    WeeklyRecapNotificationService.schedule(
                      now: DateTime.now(),
                    ),
                  );
                }
              },
            ),
            const PrivacyDataControlsSection(),
            ListTile(
              key: const Key('settings_what_thoughtprint_remembers'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                WhatThoughtprintRemembersScreen.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                'People, places, and themes remembered on this phone.',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WhatThoughtprintRemembersScreen(),
                  ),
                );
              },
            ),
            if (V1CapabilityRegistry.localAiPrivacyControls)
              KeyedSubtree(
                key: const Key('settings_on_device_processing_toggle'),
                child: SwitchListTile(
                  key: _onDeviceToggleKey,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    OnDeviceProcessingCopy.title,
                    style: ArchiveMobileTypography.listTitle(context),
                  ),
                  subtitle: Text(
                    OnDeviceProcessingCopy.subtitle,
                    style: ArchiveMobileTypography.listSubtitle(context),
                  ),
                  value: _onDeviceProcessing,
                  onChanged: _onDeviceBusy ? null : _toggleOnDeviceProcessing,
                ),
              ),
            ListTile(
              key: const Key('settings_memory_transparency_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                MemoryTransparencyCopy.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                MemoryTransparencyCopy.subtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/memory-transparency'),
            ),
            ListTile(
              key: const Key('settings_consent_audit_tile'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                ConsentAuditCopy.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              subtitle: Text(
                ConsentAuditCopy.subtitle,
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/consent-audit'),
            ),
            ListTile(
              key: const Key('settings_export_import'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Export / Import'),
              subtitle: Text(
                'Day One, Apple Notes, and a passphrase-sealed archive',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ArchiveTransferScreen(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              key: const Key('settings_journal_export_tile'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Export my journal'),
              subtitle: Text(
                'Open JSON export of non-deleted entries',
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/journal-export'),
            ),
            AppReviewAccessSettingsSection(
              onUnlocked: _onAppReviewAccessUnlocked,
            ),
            if (V1CapabilityRegistry.notifications)
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
            // Memory: when Thoughtprint may connect entries. Persistent and
            // user-only — "Memory off" stays off until changed here.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: MemoryScopeSettingsSection(),
            ),
            if (V1FeatureFlags.enableCustomReports)
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
            if (ProductionNavigation.isNavRouteVisible('/pinned-evidence'))
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
            if (ProductionNavigation.isNavRouteVisible('/archive-packs'))
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
            if (ProductionNavigation.isNavRouteVisible('/details'))
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
            if (V1FeatureFlags.enableActionItems)
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
            if (ProductionNavigation.isNavRouteVisible('/collections'))
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
            if (NotificationDebugAccess.debugMode)
              _tile(
                'Notification debug',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DebugMenuView(),
                  ),
                ),
              ),
            Text(
              ConsumerUiCopy.appVersion,
              style: ArchiveMobileTypography.cardLabel(
                context,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              key: const Key('settings_app_version'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!NotificationDebugAccess.registerTap()) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DebugMenuView(),
                  ),
                );
              },
              child: Text(
                versionLabel,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const TrustStatusFooter(),
            if (DeveloperSettingsGate.canShowDeveloperSettings) ...[
              const Divider(height: 28),
              _tile(
                'Developer diagnostics',
                onTap: () => context.push('/developer-diagnostics'),
              ),
              _tile(
                'Offline sync verify',
                onTap: () => context.push('/offline-sync-verify'),
              ),
              _tile(
                'RevenueCat verify',
                onTap: () => context.push('/revenuecat-verify'),
              ),
              _tile(
                'Restore production verify',
                onTap: () => context.push('/restore-production-verify'),
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
          color: destructive
              ? context.palette.error
              : context.palette.textPrimary,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_error_message.dart';
import '../billing/revenuecat_service.dart';
import '../billing/subscription_copy.dart';
import '../config/app_config.dart';
import '../config/developer_settings_gate.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../features/tomorrow_return/check_in_reminder_service.dart';
import '../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../product/consumer_ui_copy.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _restoreBusy = false;
  bool _remindersEnabled = false;
  bool _remindersBusy = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (!RevenueCatService.instance.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(SubscriptionCopy.temporarilyUnavailable)),
        );
      }
      return;
    }
    setState(() => _restoreBusy = true);
    try {
      final ent = await AppServices.instance.billing.restoreNative();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ent.isPro
                ? 'Subscription restored.'
                : 'No active subscription found for this account.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(e, fallback: 'Restore failed. Try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = _packageInfo == null
        ? '…'
        : '${_packageInfo!.version} (${_packageInfo!.buildNumber})';

    return PushedScreenShell(
      title: ConsumerUiCopy.settings,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _tile(
              ConsumerUiCopy.privacyPolicy,
              onTap: () => _openUrl(AppConfig.privacyUrl),
              trailing: const Icon(Icons.open_in_new, size: 18),
            ),
            _tile(
              ConsumerUiCopy.termsOfUse,
              onTap: () => _openUrl(AppConfig.termsUrl),
              trailing: const Icon(Icons.open_in_new, size: 18),
            ),
            _tile(
              ConsumerUiCopy.restorePurchases,
              onTap: _restoreBusy ? null : _restorePurchases,
            ),
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
            _tile(
              ConsumerUiCopy.exportReflections,
              onTap: () => context.push('/export'),
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

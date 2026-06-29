import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/account_auth.dart';
import '../billing/restore_purchases_flow.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_ui_copy.dart';
import '../security/app_lock_service.dart';
import '../security/app_lock_settings.dart';
import '../security/security_settings_copy.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/security/archive_privacy_controls_card.dart';
import '../widgets/security/setup_pin_screen.dart';
import '../widgets/security/wipe_local_archive_dialog.dart';
import '../security/sensitive_screen_guard.dart';

/// One place to manage archive protection and account security: app lock
/// (PIN + optional biometrics), account state, and the existing data
/// actions (export, delete, restore purchases). Only implemented actions
/// render; nothing here makes encryption or sync claims, and no archive
/// content appears.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key, this.appLock, this.auth});

  /// Injectable for tests; default to the app-wide services.
  final AppLockService? appLock;
  final AuthService? auth;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  AppLockService get _appLock => widget.appLock ?? AppLockService.instance;
  AuthService get _auth => widget.auth ?? AppServices.instance.auth;

  bool _appLockEnabled = false;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;
  bool _signedIn = false;
  bool _busy = false;
  bool _restoreBusy = false;
  RestorePurchasesFlow? _restoreFlow;
  bool _hideInAppSwitcher = false;
  bool _wipeBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final lockEnabled = await _appLock.isEnabled();
    final available = await _appLock.biometricsAvailable();
    final biometricsOn = lockEnabled && await _appLock.biometricUnlockReady();
    var signedIn = false;
    try {
      signedIn = await _auth.refreshSession() != null;
    } catch (_) {
      signedIn = _auth.currentSession != null;
    }
    if (!mounted) return;
    var hideSwitcher = false;
    try {
      hideSwitcher = await SensitiveScreenPrivacySettings.hideInAppSwitcher(
        AppServices.instance.prefs,
      );
    } catch (_) {
      hideSwitcher = false;
    }
    setState(() {
      _appLockEnabled = lockEnabled;
      _biometricsAvailable = available;
      _biometricsEnabled = biometricsOn;
      _signedIn = signedIn;
      _hideInAppSwitcher = hideSwitcher;
    });
  }

  Future<void> _setupPin({required bool changeExisting}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) =>
            SetupPinScreen(service: _appLock, changeExisting: changeExisting),
      ),
    );
    await _refresh();
  }

  Future<void> _turnOffAppLock() async {
    // The screen only renders behind an unlocked gate, so the service-side
    // unlocked-session requirement holds here.
    await _appLock.disable();
    await _refresh();
  }

  Future<void> _toggleBiometrics(bool enable) async {
    await _appLock.setBiometricsEnabled(enable);
    await _refresh();
  }

  Future<void> _openRoute(String route) async {
    await context.push(route);
    await _refresh();
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _toggleHideInAppSwitcher(bool enabled) async {
    await SensitiveScreenPrivacySettings.setHideInAppSwitcher(
      AppServices.instance.prefs,
      enabled: enabled,
    );
    await _refresh();
  }

  Future<void> _wipeLocalArchive() async {
    if (_wipeBusy) return;
    setState(() => _wipeBusy = true);
    try {
      final wiped = await showWipeLocalArchiveDialog(context);
      if (!mounted) return;
      if (wiped) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local archive data deleted.')),
        );
      }
    } finally {
      if (mounted) setState(() => _wipeBusy = false);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.userMessage)),
      );
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: SecuritySettingsCopy.title,
      body: ArchiveResponsiveLayout.page(
        context: context,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              SecuritySettingsCopy.subtitle,
              key: const Key('security_subtitle'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ArchivePrivacyControlsCard(
              deleteBusy: _wipeBusy,
              onLockTap: () {
                if (_appLockEnabled) {
                  _setupPin(changeExisting: true);
                } else {
                  _setupPin(changeExisting: false);
                }
              },
              onExportTap: () => _openRoute('/export'),
              onDeleteTap: _wipeLocalArchive,
            ),
            const SizedBox(height: AppSpacing.md),
            _sectionHeader(SecuritySettingsCopy.appLockSection),
            ..._appLockTiles(),
            const SizedBox(height: AppSpacing.md),
            _sectionHeader(SecuritySettingsCopy.accountSection),
            ..._accountTiles(),
            const SizedBox(height: AppSpacing.md),
            _sectionHeader(SecuritySettingsCopy.dataSection),
            ..._dataTiles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _appLockTiles() {
    if (!_appLockEnabled) {
      return [
        _tile(
          key: const Key('security_app_lock_status'),
          title: AppLockCopy.settingsTitle,
          subtitle:
              '${SecuritySettingsCopy.statusOff} · ${AppLockCopy.settingsBody}',
          onTap: () => _setupPin(changeExisting: false),
        ),
      ];
    }
    return [
      _tile(
        key: const Key('security_app_lock_status'),
        title: AppLockCopy.settingsTitle,
        subtitle:
            '${SecuritySettingsCopy.statusOn} · ${AppLockCopy.settingsBody} '
            '${AppLockCopy.relockTimeoutNote}',
        trailing: const SizedBox.shrink(),
      ),
      SwitchListTile(
        key: const Key('security_biometrics_switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          AppLockCopy.settingsBiometricsLabel,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        value: _biometricsEnabled,
        // Disabled (not hidden) when the device has no biometrics — the
        // PIN lock itself stays on either way.
        onChanged: _biometricsAvailable ? _toggleBiometrics : null,
      ),
      _tile(
        key: const Key('security_change_pin'),
        title: AppLockCopy.settingsChangePin,
        onTap: () => _setupPin(changeExisting: true),
      ),
      _tile(
        key: const Key('security_turn_off_app_lock'),
        title: AppLockCopy.settingsTurnOff,
        onTap: _turnOffAppLock,
      ),
    ];
  }

  List<Widget> _accountTiles() {
    final status = Text(
      _signedIn
          ? SecuritySettingsCopy.signedIn
          : SecuritySettingsCopy.notSignedIn,
      key: const Key('security_account_status'),
      style: ArchiveMobileTypography.listSubtitle(context),
    );
    if (_signedIn) {
      return [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            SecuritySettingsCopy.signOut,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: status,
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _signOut,
          key: const Key('security_sign_out'),
        ),
        Text(
          AccountAuthCopy.signOutKeepsArchive,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          SecuritySettingsCopy.signIn,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        subtitle: status,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openRoute('/account/sign-in'),
        key: const Key('security_sign_in'),
      ),
      _tile(
        key: const Key('security_create_account'),
        title: SecuritySettingsCopy.createAccount,
        onTap: () => _openRoute('/account/create'),
      ),
    ];
  }

  List<Widget> _dataTiles() {
    return [
      SwitchListTile(
        key: const Key('security_hide_app_switcher'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          SecuritySettingsCopy.hideInAppSwitcher,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        subtitle: Text(
          SecuritySettingsCopy.hideInAppSwitcherBody,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        value: _hideInAppSwitcher,
        onChanged: _toggleHideInAppSwitcher,
      ),
      _tile(
        key: const Key('security_export'),
        title: ConsumerUiCopy.exportReflections,
        onTap: () => _openRoute('/export'),
      ),
      _tile(
        key: const Key('security_wipe_local'),
        title: SecuritySettingsCopy.wipeLocalArchive,
        subtitle: SecuritySettingsCopy.wipeLocalArchiveBody,
        onTap: _wipeBusy ? null : _wipeLocalArchive,
        destructive: true,
      ),
      _tile(
        key: const Key('security_restore_purchases'),
        title: ConsumerUiCopy.restorePurchases,
        onTap: _restoreBusy ? null : _restorePurchases,
      ),
      _tile(
        key: const Key('security_delete'),
        title: ConsumerUiCopy.deleteAccount,
        onTap: () => _openRoute('/delete-account'),
        destructive: true,
      ),
    ];
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label,
        style: ArchiveMobileTypography.cardLabel(
          context,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _tile({
    Key? key,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool destructive = false,
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
      subtitle: subtitle != null
          ? Text(subtitle, style: ArchiveMobileTypography.listSubtitle(context))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

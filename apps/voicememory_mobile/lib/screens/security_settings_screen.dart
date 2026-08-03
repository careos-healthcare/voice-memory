import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/sync_recovery/sync_recovery_screen.dart';
import '../security/app_lock_service.dart';
import '../security/sensitive_screen_guard.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/security/setup_pin_screen.dart';

/// Focused V1 security settings with no experimental tools or sync engines.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({
    super.key,
    this.appLock,
    this.auth,
    @Deprecated('Restore is owned by the restore-purchases route')
    Object? restoreFlow,
    @Deprecated('Export is owned by the export route')
    Object? openDataPortability,
  });

  final AppLockService? appLock;
  final AuthService? auth;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  AppLockService get _appLock => widget.appLock ?? AppLockService.instance;
  AuthService get _auth => widget.auth ?? AppServices.instance.auth;

  bool _loading = true;
  bool _lockEnabled = false;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;
  bool _hideInSwitcher = false;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final lockEnabled = await _appLock.isEnabled();
    final biometricsAvailable = await _appLock.biometricsAvailable();
    final biometricsEnabled =
        lockEnabled && await _appLock.biometricUnlockReady();
    final hideInSwitcher =
        await SensitiveScreenPrivacySettings.hideInAppSwitcher(
          AppServices.instance.prefs,
        );
    var signedIn = _auth.currentSession != null;
    try {
      signedIn = await _auth.refreshSession() != null;
    } on Object {
      // Offline account state remains useful for local privacy controls.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _lockEnabled = lockEnabled;
      _biometricsAvailable = biometricsAvailable;
      _biometricsEnabled = biometricsEnabled;
      _hideInSwitcher = hideInSwitcher;
      _signedIn = signedIn;
    });
  }

  Future<void> _configurePin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SetupPinScreen(service: _appLock, changeExisting: _lockEnabled),
      ),
    );
    await _refresh();
  }

  Future<void> _disableLock() async {
    await _appLock.disable();
    await _refresh();
  }

  Future<void> _setBiometrics(bool enabled) async {
    await _appLock.setBiometricsEnabled(enabled);
    await _refresh();
  }

  Future<void> _setHideInSwitcher(bool enabled) async {
    await SensitiveScreenPrivacySettings.setHideInAppSwitcher(
      AppServices.instance.prefs,
      enabled: enabled,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy and security')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                key: const Key('security_app_lock'),
                leading: const Icon(Icons.lock_outline),
                title: Text(_lockEnabled ? 'Change app PIN' : 'Set app PIN'),
                subtitle: const Text(
                  'Protect ArchiveMe when someone has access to this device.',
                ),
                onTap: _configurePin,
              ),
              if (_lockEnabled)
                SwitchListTile(
                  key: const Key('security_biometrics'),
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Unlock with biometrics'),
                  value: _biometricsEnabled,
                  onChanged: _biometricsAvailable ? _setBiometrics : null,
                ),
              if (_lockEnabled)
                ListTile(
                  key: const Key('security_disable_lock'),
                  leading: const Icon(Icons.lock_open),
                  title: const Text('Turn off app lock'),
                  onTap: _disableLock,
                ),
              SwitchListTile(
                key: const Key('security_hide_app_switcher'),
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide content in the app switcher'),
                value: _hideInSwitcher,
                onChanged: _setHideInSwitcher,
              ),
              const Divider(),
              _RouteTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy controls',
                route: '/privacy-trust-centre',
              ),
              _RouteTile(
                icon: Icons.download_outlined,
                title: 'Export archive',
                route: '/export',
              ),
              ListTile(
                key: const Key('security_sync_recovery'),
                leading: const Icon(Icons.key_outlined),
                title: const Text('Encrypted sync recovery'),
                subtitle: const Text(
                  'Optional code for restoring your sync key on a new device',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SyncRecoveryScreen()),
                ),
              ),
              _RouteTile(
                icon: Icons.restore,
                title: 'Restore purchases',
                route: '/restore-purchases',
              ),
              if (_signedIn)
                ListTile(
                  key: const Key('security_sign_out'),
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    await _auth.signOut();
                    await _refresh();
                  },
                ),
              _RouteTile(
                icon: Icons.delete_outline,
                title: 'Delete account and archive',
                route: '/delete-account',
              ),
            ],
          ),
  );
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}

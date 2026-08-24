import 'dart:async';

import 'package:archiveme_mobile/features/privacy/database_biometric_gate_store.dart';
import 'package:archiveme_mobile/security/secure_database_copy.dart';
import 'package:archiveme_mobile/features/auth/security/secure_database_unlock_screen.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Observes lifecycle transitions, locks SQLCipher on background, and requires
/// biometrics before reopening the local database.
class SecureDatabaseGate extends StatefulWidget {
  const SecureDatabaseGate({required this.child, super.key, this.lockService});

  final Widget child;
  final SecureSqliteLockService? lockService;

  @override
  State<SecureDatabaseGate> createState() => _SecureDatabaseGateState();
}

class _SecureDatabaseGateState extends State<SecureDatabaseGate>
    with WidgetsBindingObserver {
  SecureSqliteLockService get _lock =>
      widget.lockService ?? SecureSqliteLockService.instance;

  bool? _locked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock.addListener(_refreshLockedState);
    unawaited(_refreshLockedState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock.removeListener(_refreshLockedState);
    super.dispose();
  }

  Future<void> _refreshLockedState() async {
    if (!SecureSqliteLockService.encryptionEnabled) {
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }
    await DatabaseBiometricGateStore.ensureLoaded();
    if (!DatabaseBiometricGateStore.enabled) {
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }
    final locked = _lock.isLocked;
    if (!mounted) return;
    setState(() => _locked = locked);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_lock.lockDatabaseFromLifecycle().then((_) => _refreshLockedState()));
      case AppLifecycleState.resumed:
        unawaited(() async {
          await DatabaseBiometricGateStore.ensureLoaded();
          if (!DatabaseBiometricGateStore.enabled && _lock.isLocked) {
            await _lock.bootstrapUnlockedSession();
            if (AppServices.isInitialized) {
              await AppServices.instance.reopenSqliteDatabase();
            }
          } else {
            await _lock.onAppResumed();
          }
          await _refreshLockedState();
          if (AppServices.isInitialized && _locked == false) {
            unawaited(AppServices.instance.processQuickCaptureWidgetQueue());
          }
        }());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _reopenDatabaseAfterUnlock() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.reopenSqliteDatabase();
    await _refreshLockedState();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    if (locked == null) {
      return const ColoredBox(
        key: Key('secure_database_loading'),
        color: AppColors.backgroundPrimary,
      );
    }
    if (locked) {
      return SecureDatabaseUnlockScreen(
        lockService: _lock,
        onUnlocked: _reopenDatabaseAfterUnlock,
      );
    }
    return widget.child;
  }
}

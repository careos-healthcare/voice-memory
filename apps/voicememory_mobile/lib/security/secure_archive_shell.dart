import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';

import '../theme/app_colors.dart';
import '../features/privacy/biometric_lock_overlay.dart';
import '../services/security/biometric_vault_service.dart';
import 'app_lock_gate.dart';
import 'app_lock_service.dart';
import 'app_privacy_shell.dart';

/// Native task-switcher protection plus the app's biometric/PIN lock gate.
class SecureArchiveShell extends StatefulWidget {
  const SecureArchiveShell({
    super.key,
    required this.child,
    this.appLock,
    this.biometricVault,
  });

  final Widget child;
  final AppLockService? appLock;
  final BiometricVaultService? biometricVault;

  @override
  State<SecureArchiveShell> createState() => _SecureArchiveShellState();
}

class _SecureArchiveShellState extends State<SecureArchiveShell>
    with WidgetsBindingObserver {
  late final SecureApplicationController _controller =
      SecureApplicationController(SecureApplicationState(secured: true));
  bool _coverVisible = false;

  AppLockService get _appLock => widget.appLock ?? AppLockService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.secure();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _removePrivacyCover() {
    if (mounted && _coverVisible) {
      setState(() => _coverVisible = false);
    }
    _controller.authSuccess(unlock: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldCover = switch (state) {
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden => true,
      AppLifecycleState.resumed || AppLifecycleState.detached => false,
    };
    if (shouldCover && !_coverVisible && mounted) {
      setState(() => _coverVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      secureApplicationController: _controller,
      autoUnlockNative: false,
      onNeedUnlock: (_) async => null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppLockGate(
            service: _appLock,
            onResumeProtected: _removePrivacyCover,
            child: BiometricLockOverlay(
              service: widget.biometricVault,
              child: AppPrivacyShell(appLock: _appLock, child: widget.child),
            ),
          ),
          if (_coverVisible)
            const ColoredBox(
              key: Key('secure_task_switcher_overlay'),
              color: AppColors.backgroundPrimary,
            ),
        ],
      ),
    );
  }
}

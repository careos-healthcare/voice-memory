import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'app_lock_service.dart';
import 'router_location.dart';
import 'sensitive_screen_guard.dart';

/// App-wide privacy overlay driven by route sensitivity and user settings.
class AppPrivacyShell extends StatefulWidget {
  const AppPrivacyShell({super.key, required this.child, this.appLock});

  final Widget child;
  final AppLockService? appLock;

  @override
  State<AppPrivacyShell> createState() => _AppPrivacyShellState();
}

class _AppPrivacyShellState extends State<AppPrivacyShell> {
  bool _hideInAppSwitcher = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = AppServices.instance.prefs;
      final hide = await SensitiveScreenPrivacySettings.hideInAppSwitcher(
        prefs,
      );
      if (mounted) setState(() => _hideInAppSwitcher = hide);
    } catch (_) {
      // Tests may run without AppServices — default stays false.
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = RouterLocation.currentPath(context);
    final routeIsSensitive =
        location != null && SensitiveRoutes.isSensitiveRoute(location);
    return SensitiveScreenGuard(
      appLock: widget.appLock ?? AppLockService.instance,
      hideInAppSwitcher: _hideInAppSwitcher,
      routeIsSensitive: routeIsSensitive,
      child: widget.child,
    );
  }
}

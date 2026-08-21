import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/router_location.dart';
import 'package:archiveme_mobile/security/sensitive_screen_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// App-wide privacy overlay driven by route sensitivity and user settings.
class AppPrivacyShell extends StatefulWidget {
  const AppPrivacyShell({required this.child, super.key, this.appLock});

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
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = AppServices.instance.prefs;
      final hide = await SensitiveScreenPrivacySettings.hideInAppSwitcher(
        prefs,
      );
      if (mounted) setState(() => _hideInAppSwitcher = hide);
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
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
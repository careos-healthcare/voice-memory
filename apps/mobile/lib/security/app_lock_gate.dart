import 'dart:async';

import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/features/settings/security/app_lock_screen.dart';
import 'package:flutter/material.dart';

/// Wraps the whole app. While the lock state is unknown or locked, nothing
/// from the archive renders — only a blank surface or the lock screen.
/// Also observes the app lifecycle: backgrounding starts the re-lock
/// timer and resuming re-locks after the timeout.
class AppLockGate extends StatefulWidget {
  const AppLockGate({required this.child, super.key, this.service});

  final Widget child;

  /// Injectable for tests; defaults to the process-wide service.
  final AppLockService? service;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  AppLockService get _service => widget.service ?? AppLockService.instance;

  /// Null while loading — content stays hidden until the state is known.
  bool? _locked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final locked = await _service.isLocked();
    if (!mounted) return;
    setState(() => _locked = locked);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _service.onAppBackgrounded();
      case AppLifecycleState.resumed:
        unawaited(_service.onAppResumed().then((_) => _refresh()));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    if (locked == null) {
      // State unknown: render a blank surface, never archive content.
      return const ColoredBox(
        key: Key('app_lock_loading'),
        color: AppColors.backgroundPrimary,
      );
    }
    if (locked) return AppLockScreen(service: _service);
    return widget.child;
  }
}
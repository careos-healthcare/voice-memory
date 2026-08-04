import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/security/app_lock_screen.dart';
import '../services/app_services.dart';
import 'app_lock_service.dart';

/// Wraps the whole app. While the lock state is unknown or locked, nothing
/// from the archive renders — only a blank surface or the lock screen.
/// Also observes the app lifecycle: backgrounding starts the re-lock
/// timer and resuming re-locks after the timeout.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.service,
    this.onUnlocked,
    this.onResumeProtected,
  });

  final Widget child;

  /// Injectable for tests; defaults to the process-wide service.
  final AppLockService? service;

  /// Injectable drain trigger for tests.
  final Future<void> Function()? onUnlocked;

  /// Called after the resumed lock state has rendered. Privacy shells use this
  /// to remove their native task-switcher cover without exposing one frame of
  /// archive content.
  final VoidCallback? onResumeProtected;

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
    if (!locked) {
      unawaited(_resumeForegroundServices());
    }
  }

  Future<void> _resumeForegroundServices() async {
    final callback = widget.onUnlocked;
    if (callback != null) {
      await callback();
      return;
    }
    if (!AppServices.isInitialized) return;
    await Future.wait([
      AppServices.instance.drainEncryptedGraphSyncQueue(),
      AppServices.instance.drainCaptureApiRetryQueue(),
      AppServices.instance.onForegroundUnlocked(),
      AppServices.instance.subscriptionRepository.refresh(force: true),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _service.onAppBackgrounded();
        if (AppServices.isInitialized) {
          unawaited(AppServices.instance.onBackgroundLocked());
        }
        break;
      case AppLifecycleState.resumed:
        unawaited(_handleResume());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _handleResume() async {
    await _service.onAppResumed();
    await _refresh();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onResumeProtected?.call();
    });
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

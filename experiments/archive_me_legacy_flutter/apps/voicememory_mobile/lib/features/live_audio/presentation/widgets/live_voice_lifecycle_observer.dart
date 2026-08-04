import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/live_voice_lifecycle_policy.dart';
import '../offline_vault_recovery_launch_controller.dart';

/// Observes app lifecycle to flush live capture, sweep vault recovery, and prompt restore.
class LiveVoiceLifecycleObserver extends StatefulWidget {
  const LiveVoiceLifecycleObserver({
    super.key,
    required this.child,
    required this.lifecyclePolicy,
    this.onUncommittedSessionDetected,
  });

  final Widget child;
  final LiveVoiceLifecyclePolicy lifecyclePolicy;
  final VoidCallback? onUncommittedSessionDetected;

  @override
  State<LiveVoiceLifecycleObserver> createState() =>
      _LiveVoiceLifecycleObserverState();
}

class _LiveVoiceLifecycleObserverState extends State<LiveVoiceLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForRecoverableSession());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForRecoverableSession() async {
    await OfflineVaultRecoveryLaunchController.prepareScan();
    final hasPending = await widget.lifecyclePolicy.hasUncommittedVaultData();
    if (!hasPending || !mounted) {
      return;
    }

    if (widget.onUncommittedSessionDetected != null) {
      widget.onUncommittedSessionDetected!();
      return;
    }

    await OfflineVaultRecoveryLaunchController.maybePromptRecovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        widget.lifecyclePolicy.onAppBackgrounded();
      case AppLifecycleState.resumed:
        widget.lifecyclePolicy.onAppResumed();
      case AppLifecycleState.detached:
        widget.lifecyclePolicy.onAppTerminated();
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

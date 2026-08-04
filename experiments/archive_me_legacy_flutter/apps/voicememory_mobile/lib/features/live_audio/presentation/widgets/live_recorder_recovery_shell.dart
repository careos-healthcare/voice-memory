import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../services/app_services.dart';
import '../../application/live_voice_lifecycle_policy.dart';
import '../../domain/models/offline_vault_manifest.dart';
import '../offline_vault_recovery_launch_controller.dart';
import 'emergency_vault_recovery_banner.dart';
import 'live_voice_lifecycle_observer.dart';

/// Wraps primary recording surfaces with lifecycle handling and vault recovery UI.
class LiveRecorderRecoveryShell extends StatefulWidget {
  const LiveRecorderRecoveryShell({
    super.key,
    required this.child,
    this.lifecyclePolicy,
  });

  final Widget child;
  final LiveVoiceLifecyclePolicy? lifecyclePolicy;

  static final GlobalKey<State<LiveRecorderRecoveryShell>> shellKey =
      GlobalKey<State<LiveRecorderRecoveryShell>>();

  static Future<void> refreshPending() {
    final state = shellKey.currentState;
    if (state is _LiveRecorderRecoveryShellState) {
      return state._refreshPending();
    }
    return Future<void>.value();
  }

  @override
  State<LiveRecorderRecoveryShell> createState() =>
      _LiveRecorderRecoveryShellState();
}

class _LiveRecorderRecoveryShellState extends State<LiveRecorderRecoveryShell> {
  late final LiveVoiceLifecyclePolicy _lifecyclePolicy;
  OfflineVaultManifest? _manifest;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lifecyclePolicy = widget.lifecyclePolicy ?? LiveVoiceLifecyclePolicy();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPending());
    });
  }

  Future<void> _refreshPending() async {
    await OfflineVaultRecoveryLaunchController.refreshPending();
    if (!mounted) return;
    setState(() {
      _manifest = OfflineVaultRecoveryLaunchController.pendingManifest;
      _error = null;
      if (_manifest == null) {
        _busy = false;
      }
    });
  }

  Future<void> _handleRestore() async {
    final manifest = _manifest;
    if (manifest == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AppServices.instance.offlineVaultRecovery!.recoverVault(manifest);
      await _refreshPending();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Restore failed. Try again when you are back online.';
      });
    }
  }

  Future<void> _handleDiscard() async {
    final manifest = _manifest;
    if (manifest == null || _busy) return;

    setState(() => _busy = true);
    try {
      await AppServices.instance.offlineVaultRecovery!.discardVault(manifest);
      await _refreshPending();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool get _showBanner {
    final manifest = _manifest;
    return manifest != null && manifest.serverRecoverable && manifest.isPending;
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;

    return LiveVoiceLifecycleObserver(
      lifecyclePolicy: _lifecyclePolicy,
      onUncommittedSessionDetected: () {
        unawaited(_refreshPending());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showBanner && manifest != null)
            EmergencyVaultRecoveryBanner(
              recoveredChunkCount: manifest.frameCount > 0
                  ? manifest.frameCount
                  : 1,
              totalDuration: Duration(seconds: manifest.durationSeconds),
              onRecover: _handleRestore,
              onDiscard: _handleDiscard,
              isBusy: _busy,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

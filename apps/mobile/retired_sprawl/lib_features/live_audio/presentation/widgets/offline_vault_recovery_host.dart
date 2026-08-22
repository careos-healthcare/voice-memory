import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/offline_vault_recovery_launch_controller.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prompts for pending offline vault recovery after startup and on app resume.
class OfflineVaultRecoveryHost extends ConsumerStatefulWidget {
  const OfflineVaultRecoveryHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineVaultRecoveryHost> createState() =>
      _OfflineVaultRecoveryHostState();
}

class _OfflineVaultRecoveryHostState
    extends ConsumerState<OfflineVaultRecoveryHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!V1CapabilityRegistry.liveVoice) return;
      unawaited(OfflineVaultRecoveryLaunchController.maybePromptRecovery());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!V1CapabilityRegistry.liveVoice) return;
    if (state == AppLifecycleState.resumed) {
      AppServices.instance.liveVoiceRecoveryGateway
          .notifyConnectivityRestored();
      unawaited(OfflineVaultRecoveryLaunchController.onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../services/app_services.dart';
import '../offline_vault_recovery_launch_controller.dart';

/// Prompts for pending offline vault recovery after startup and on app resume.
class OfflineVaultRecoveryHost extends StatefulWidget {
  const OfflineVaultRecoveryHost({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineVaultRecoveryHost> createState() =>
      _OfflineVaultRecoveryHostState();
}

class _OfflineVaultRecoveryHostState extends State<OfflineVaultRecoveryHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (state == AppLifecycleState.resumed) {
      AppServices.instance.liveVoiceRecoveryGateway
          .notifyConnectivityRestored();
      unawaited(OfflineVaultRecoveryLaunchController.onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

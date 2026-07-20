import 'package:flutter/material.dart';

import '../../../router/app_router.dart';
import '../../../services/app_services.dart';
import '../application/offline_vault_recovery_service.dart';
import '../domain/models/offline_vault_manifest.dart';
import 'widgets/offline_vault_recovery_modal.dart';

/// Scans for pending vaults on foreground and prompts recovery upload once per session.
class OfflineVaultRecoveryLaunchController {
  OfflineVaultRecoveryLaunchController._();

  static bool _scanComplete = false;
  static bool _promptShownThisSession = false;
  static List<OfflineVaultManifest> _pending = const [];

  static OfflineVaultRecoveryService get _recovery =>
      AppServices.instance.offlineVaultRecovery;

  static Future<void> prepareScan() async {
    if (_scanComplete) return;
    _pending = await _recovery.scanPendingVaults();
    _scanComplete = true;
  }

  static Future<void> onAppResumed() async {
    _scanComplete = false;
    await prepareScan();
    await maybePromptRecovery();
  }

  static Future<void> maybePromptRecovery() async {
    if (_promptShownThisSession) return;
    if (!_scanComplete) {
      await prepareScan();
    }
    if (_pending.isEmpty) return;

    final context = appRootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _promptShownThisSession = true;
    final manifest = _pending.first;
    await showOfflineVaultRecoveryModal(
      context: context,
      manifest: manifest,
      onRecover: () => _recovery.recoverVault(manifest),
      onDiscard: () => _recovery.discardVault(manifest),
    );

    _pending = await _recovery.scanPendingVaults();
    if (_pending.isNotEmpty) {
      _promptShownThisSession = false;
    }
  }

  static void resetForTest() {
    _scanComplete = false;
    _promptShownThisSession = false;
    _pending = const [];
  }
}

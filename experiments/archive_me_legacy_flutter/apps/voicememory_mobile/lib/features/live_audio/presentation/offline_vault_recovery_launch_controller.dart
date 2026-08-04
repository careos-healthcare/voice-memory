import '../../../services/app_services.dart';
import '../application/offline_vault_recovery_service.dart';
import '../domain/models/offline_vault_manifest.dart';
import 'widgets/live_recorder_recovery_shell.dart';

/// Scans for pending vaults on foreground and surfaces the recovery banner.
class OfflineVaultRecoveryLaunchController {
  OfflineVaultRecoveryLaunchController._();

  static bool _scanComplete = false;
  static List<OfflineVaultManifest> _pending = const [];

  static OfflineVaultManifest? get pendingManifest =>
      _pending.isEmpty ? null : _pending.first;

  static OfflineVaultRecoveryService get _recovery =>
      AppServices.instance.offlineVaultRecovery!;

  static Future<void> prepareScan() async {
    if (_scanComplete) return;
    _pending = await _recovery.scanPendingVaults();
    _scanComplete = true;
  }

  static Future<void> refreshPending() async {
    _scanComplete = false;
    await prepareScan();
  }

  static Future<void> onAppResumed() async {
    await refreshPending();
    await maybePromptRecovery();
  }

  static Future<void> maybePromptRecovery() async {
    if (!_scanComplete) {
      await prepareScan();
    }
    if (_pending.isEmpty) return;
    await LiveRecorderRecoveryShell.refreshPending();
  }

  static void resetForTest() {
    _scanComplete = false;
    _pending = const [];
  }
}

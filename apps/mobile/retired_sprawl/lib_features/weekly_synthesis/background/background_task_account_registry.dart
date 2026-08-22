import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// Persists the active account namespace for headless WorkManager tasks.
abstract final class BackgroundTaskAccountRegistry {
  BackgroundTaskAccountRegistry._();

  static const _storageKey = 'background_task_active_namespace_v1';

  static Future<void> persistActiveNamespace(AccountNamespace namespace) async {
    await SecureStorageService().write(_storageKey, namespace.key);
  }

  static Future<AccountNamespace> readActiveNamespace() async {
    final raw = await SecureStorageService().read(_storageKey);
    return AccountNamespace.fromStorageKey(raw ?? '');
  }
}

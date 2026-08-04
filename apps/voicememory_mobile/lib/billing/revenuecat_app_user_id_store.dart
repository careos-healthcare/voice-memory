import 'package:uuid/uuid.dart';

import '../storage/secure_storage.dart';

/// Persists the custom RevenueCat identity independently of login state.
class RevenueCatAppUserIdStore {
  RevenueCatAppUserIdStore({SecureStorageService? secureStorage, Uuid? uuid})
    : _secureStorage = secureStorage ?? SecureStorageService(),
      _uuid = uuid ?? const Uuid();

  static const storageKey = 'revenuecat_app_user_id_v1';

  final SecureStorageService _secureStorage;
  final Uuid _uuid;

  Future<String> getOrCreate() async {
    final existing = await _secureStorage.read(storageKey);
    if (existing != null && isValidUuid(existing)) {
      return existing.toLowerCase();
    }

    final created = _uuid.v4().toLowerCase();
    await _secureStorage.write(storageKey, created);
    return created;
  }

  static bool isValidUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

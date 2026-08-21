import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// Offline entitlement snapshot — persisted in flutter_secure_storage when available.
class EntitlementCache {
  EntitlementCache({
    required this.file,
    SecureStorageService? secureStorage,
  }) : _secureStorage = secureStorage;

  static const _secureKey = 'entitlements_v1';

  final File file;
  final SecureStorageService? _secureStorage;

  static Future<EntitlementCache> open(
    String filePath, {
    SecureStorageService? secureStorage,
  }) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return EntitlementCache(file: file, secureStorage: secureStorage);
  }

  Future<PremiumEntitlements?> load() async {
    final fromSecure = await _loadFromSecureStorage();
    if (fromSecure != null) return fromSecure;

    final fromFile = await _loadFromFile();
    if (fromFile != null && _secureStorage != null) {
      await _saveToSecureStorage(fromFile);
    }
    return fromFile;
  }

  Future<void> save(PremiumEntitlements entitlements) async {
    if (_secureStorage != null) {
      await _saveToSecureStorage(entitlements);
      return;
    }
    await file.writeAsString(jsonEncode(entitlements.toJson()));
  }

  Future<void> clear() async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(_secureKey);
    }
    if (await file.exists()) await file.delete();
  }

  Future<PremiumEntitlements?> _loadFromSecureStorage() async {
    final secure = _secureStorage;
    if (secure == null) return null;
    try {
      final raw = await secure.read(_secureKey);
      if (raw == null || raw.trim().isEmpty) return null;
      return PremiumEntitlements.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_, stackTrace) {
      return null;
    }
  }

  Future<void> _saveToSecureStorage(PremiumEntitlements entitlements) async {
    final secure = _secureStorage;
    if (secure == null) return;
    await secure.write(_secureKey, jsonEncode(entitlements.toJson()));
  }

  Future<PremiumEntitlements?> _loadFromFile() async {
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return PremiumEntitlements.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_, stackTrace) {
      return null;
    }
  }
}
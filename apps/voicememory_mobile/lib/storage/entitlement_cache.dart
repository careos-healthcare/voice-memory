import 'dart:convert';
import 'dart:io';

import '../models/entitlement.dart';

class EntitlementCache {
  EntitlementCache({required this.file, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final File file;
  final DateTime Function() _now;

  /// Maximum time a previously verified Pro entitlement may unlock features
  /// without a fresh server or RevenueCat verification.
  static const Duration maxOfflineProAge = Duration(days: 5);

  static Future<EntitlementCache> open(
    String filePath, {
    DateTime Function()? now,
  }) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return EntitlementCache(file: file, now: now);
  }

  Future<PremiumEntitlements?> load() async {
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entitlementJson = decoded['entitlements'];
      final entitlements = PremiumEntitlements.fromJson(
        entitlementJson is Map
            ? Map<String, dynamic>.from(entitlementJson)
            : decoded,
      );
      if (!entitlements.isPro) return entitlements;

      final cachedAt = DateTime.tryParse(decoded['cachedAt'] as String? ?? '');
      if (cachedAt == null || !_isFresh(cachedAt)) {
        await clear();
        return null;
      }
      return entitlements.copyWith(
        verifiedAt: cachedAt,
        verification: EntitlementVerification.cached,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PremiumEntitlements entitlements) async {
    final envelope = {
      'version': 1,
      'cachedAt': (entitlements.verifiedAt ?? _now()).toUtc().toIso8601String(),
      'entitlements': entitlements.toJson(),
    };
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(envelope), flush: true);
    await temporary.rename(file.path);
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }

  bool _isFresh(DateTime cachedAt) {
    final age = _now().toUtc().difference(cachedAt.toUtc());
    return !age.isNegative && age < maxOfflineProAge;
  }
}

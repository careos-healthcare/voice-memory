import 'dart:convert';
import 'dart:io';

import '../models/entitlement.dart';

class EntitlementCache {
  EntitlementCache({required this.file});

  final File file;

  static Future<EntitlementCache> open(String filePath) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return EntitlementCache(file: file);
  }

  Future<PremiumEntitlements?> load() async {
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return PremiumEntitlements.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PremiumEntitlements entitlements) async {
    await file.writeAsString(jsonEncode(entitlements.toJson()));
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}

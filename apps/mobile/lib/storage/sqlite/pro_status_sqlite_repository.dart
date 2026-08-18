import 'dart:convert';

import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite mirror of the account Pro/Free entitlement snapshot.
class ProStatusSqliteRepository {
  ProStatusSqliteRepository(this._sqlite);

  static const table = 'account_pro_status';
  static const singletonRowId = 1;

  final AppSqliteDatabase _sqlite;

  Future<ProStatusRecord?> load() async {
    final rows = await _sqlite.database.query(
      table,
      where: 'id = ?',
      whereArgs: [singletonRowId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  Future<void> save(
    PremiumEntitlements entitlements, {
    required String syncedFrom,
  }) async {
    await _sqlite.database.insert(
      table,
      _rowFor(entitlements, syncedFrom: syncedFrom),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear() async {
    await _sqlite.database.delete(
      table,
      where: 'id = ?',
      whereArgs: [singletonRowId],
    );
  }

  Map<String, Object?> _rowFor(
    PremiumEntitlements entitlements, {
    required String syncedFrom,
  }) {
    return {
      'id': singletonRowId,
      'is_pro': entitlements.isPro ? 1 : 0,
      'tier': entitlements.isPro ? 'pro' : 'free',
      'source': entitlements.source,
      'entitlement_ids_json': jsonEncode(entitlements.entitlementIds),
      'billing_connected': entitlements.billingConnected ? 1 : 0,
      'synced_from': syncedFrom,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
  }

  ProStatusRecord _recordFromRow(Map<String, Object?> row) {
    final idsRaw = row['entitlement_ids_json'] as String? ?? '[]';
    var entitlementIds = const <String>[];
    try {
      final decoded = jsonDecode(idsRaw);
      if (decoded is List) {
        entitlementIds = decoded.map((value) => value.toString()).toList();
      }
    } catch (_) {
      entitlementIds = const [];
    }

    final tierRaw = row['tier'] as String? ?? 'free';
    return ProStatusRecord(
      entitlements: PremiumEntitlements(
        tier: tierRaw == 'pro' ? BillingTier.pro : BillingTier.free,
        entitlementIds: entitlementIds,
        billingConnected: (row['billing_connected'] as int? ?? 0) == 1,
        source: row['source'] as String? ?? 'unknown',
      ),
      syncedFrom: row['synced_from'] as String? ?? 'unknown',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? 0,
        isUtc: true,
      ),
    );
  }
}

class ProStatusRecord {
  const ProStatusRecord({
    required this.entitlements,
    required this.syncedFrom,
    required this.updatedAt,
  });

  final PremiumEntitlements entitlements;
  final String syncedFrom;
  final DateTime updatedAt;
}
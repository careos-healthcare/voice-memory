import 'dart:convert';

import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:crypto/crypto.dart';

/// Append-only caregiver audit log — structural metadata only.
class CaregiverAuditStore {
  CaregiverAuditStore(this._prefs);

  static const prefsKey = 'caregiver_audit_log_v1';

  final MobilePrefsStore _prefs;
  final List<AuditLogEntry> _cache = [];
  bool _loaded = false;

  List<AuditLogEntry> get entries => List.unmodifiable(_cache);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await _prefs.readJsonMap(prefsKey);
    final rows = raw?['entries'];
    _cache
      ..clear()
      ..addAll(
        rows is List
            ? rows
                .whereType<Map>()
                .map((row) => AuditLogEntry.fromJson(Map<String, dynamic>.from(row)))
            : const <AuditLogEntry>[],
      );
    _loaded = true;
  }

  Future<AuditLogEntry> append({
    required String sessionId,
    required CaregiverAuditAction action,
    required String resourceType,
    String? resourceId,
    Map<String, Object?> metadata = const {},
    DateTime? now,
  }) async {
    await ensureLoaded();
    final timestamp = (now ?? DateTime.now()).toUtc();
    final entry = AuditLogEntry(
      entryId: _digest('$sessionId|${action.wireValue}|${timestamp.toIso8601String()}'),
      sessionId: sessionId,
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      timestamp: timestamp,
      metadata: metadata,
    );
    _cache.add(entry);
    await _persist();
    return entry;
  }

  Future<void> _persist() async {
    await _prefs.writeJsonMap(prefsKey, {
      'entries': _cache.map((e) => e.toJson()).toList(),
    });
  }

  static String _digest(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
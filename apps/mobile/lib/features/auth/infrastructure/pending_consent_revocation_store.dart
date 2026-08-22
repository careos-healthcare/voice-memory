import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Short, non-identifying codes recorded against a queued revocation.
///
/// Deliberately a closed set of literals: [PendingConsentRevocation.lastError]
/// is persisted to plain prefs, so it must never carry a server message, a
/// grantee name, or anything else derived from the archive.
abstract final class ConsentRevocationFailureCode {
  ConsentRevocationFailureCode._();

  static const network = 'network';
  static const backendNotConfigured = 'backend_not_configured';
  static const authRequired = 'auth_required';
  static const serverUnavailable = 'server_unavailable';
  static const notConfirmed = 'not_confirmed';
  static const forbidden = 'forbidden';
  static const invalidRequest = 'invalid_request';

  /// Codes the server will keep rejecting no matter how often we ask.
  static const permanent = <String>{forbidden, invalidRequest};

  static bool isPermanent(String? code) => code != null && permanent.contains(code);
}

/// One grant whose local revocation has not yet been mirrored to the server.
class PendingConsentRevocation {
  const PendingConsentRevocation({
    required this.tokenId,
    required this.domain,
    required this.queuedAt,
    required this.attempts,
    this.lastError,
  });

  /// Returns null for rows that cannot be acted on — an entry with no token id
  /// or an unrecognised domain has nothing the revoke endpoint could accept.
  static PendingConsentRevocation? fromJson(Map<String, dynamic> json) {
    final tokenId = json['tokenId']?.toString().trim();
    if (tokenId == null || tokenId.isEmpty) return null;
    final domain = ConsentRevocationDomain.fromWire(json['domain']?.toString());
    if (domain == null) return null;
    final rawAttempts = json['attempts'];
    final lastError = json['lastError']?.toString().trim();
    return PendingConsentRevocation(
      tokenId: tokenId,
      domain: domain,
      queuedAt:
          DateTime.tryParse(json['queuedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attempts: rawAttempts is num ? rawAttempts.toInt() : 0,
      lastError: lastError == null || lastError.isEmpty ? null : lastError,
    );
  }

  final String tokenId;
  final ConsentRevocationDomain domain;
  final DateTime queuedAt;
  final int attempts;
  final String? lastError;

  /// True when the server has refused this grant for a reason retrying cannot
  /// change. The entry stays in the queue regardless — see the class docs on
  /// [PendingConsentRevocationStore].
  bool get isPermanentlyRejected =>
      ConsentRevocationFailureCode.isPermanent(lastError);

  PendingConsentRevocation recordAttempt({String? failureCode}) =>
      PendingConsentRevocation(
        tokenId: tokenId,
        domain: domain,
        queuedAt: queuedAt,
        attempts: attempts + 1,
        lastError: failureCode,
      );

  /// Reconciles this entry with one already on disk, keeping the earliest queue
  /// time and the highest attempt count so neither writer can undercount.
  PendingConsentRevocation mergeWith(PendingConsentRevocation stored) =>
      PendingConsentRevocation(
        tokenId: tokenId,
        domain: domain,
        queuedAt: queuedAt.isBefore(stored.queuedAt) ? queuedAt : stored.queuedAt,
        attempts: attempts > stored.attempts ? attempts : stored.attempts,
        lastError: lastError ?? stored.lastError,
      );

  Map<String, dynamic> toJson() => {
    'tokenId': tokenId,
    'domain': domain.wireValue,
    'queuedAt': queuedAt.toIso8601String(),
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };
}

/// Durable queue of revocations the device still owes the server.
///
/// Local revocation is never gated on the network, so the server call is the
/// part that can fail. An entry lands here the moment that call does not come
/// back confirmed, and leaves only when the server confirms — including the
/// idempotent `alreadyRevoked` case. A transient failure, a high attempt
/// count, or a permanent `403` never drops an entry: a revocation the user
/// believes they made must stay visible as unfinished rather than vanish.
///
/// Backed by [MobilePrefsStore] like `ConsentRevocationStore`, and persisted
/// through [MobilePrefsStore.updateMap] so the read-merge-write runs as one
/// critical section. Two holders of a concurrently-loaded view therefore union
/// rather than clobber, which is the failure that once silently reinstated
/// revoked access through the duplicated revocation store.
///
/// The signed token itself is deliberately not persisted here. It is offered
/// to the server as an ownership-proof fallback only while the process that
/// revoked it is still alive; writing a copy to disk would leave a replayable
/// token behind exactly when the user asked for it to be gone.
abstract final class PendingConsentRevocationStore {
  PendingConsentRevocationStore._();

  static const prefsKey = 'consent_pending_server_revocations_v1';

  static final Map<String, PendingConsentRevocation> _pending = {};

  /// Token ids this process has seen the server confirm. Kept so a merge
  /// against a stale on-disk copy cannot resurrect a settled entry.
  static final Set<String> _confirmed = <String>{};

  static bool _loaded = false;

  /// Test seam for the persistence path — see `ConsentRevocationStore`.
  @visibleForTesting
  static MobilePrefsStore? debugPrefsOverride;

  static MobilePrefsStore? get _prefs =>
      debugPrefsOverride ??
      (AppServices.isInitialized ? AppServices.instance.prefs : null);

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = _prefs;
    if (prefs == null) {
      _loaded = true;
      return;
    }
    _adopt(await prefs.readJsonMap(prefsKey));
    _loaded = true;
  }

  /// Oldest first, so a flush retries in the order the user revoked.
  static List<PendingConsentRevocation> get entries =>
      _pending.values.toList()..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

  static PendingConsentRevocation? entryFor(String tokenId) =>
      _pending[tokenId.trim()];

  static bool contains(String tokenId) => _pending.containsKey(tokenId.trim());

  /// Records that [tokenId] still owes the server a revocation.
  ///
  /// Idempotent by token id: a second enqueue for the same grant updates the
  /// existing entry's attempt count instead of adding a duplicate.
  static Future<void> enqueue({
    required String tokenId,
    required ConsentRevocationDomain domain,
    String? failureCode,
    DateTime? now,
  }) async {
    final id = tokenId.trim();
    if (id.isEmpty) return;
    await ensureLoaded();
    _confirmed.remove(id);
    final existing = _pending[id];
    _pending[id] = existing == null
        ? PendingConsentRevocation(
            tokenId: id,
            domain: domain,
            queuedAt: (now ?? DateTime.now()).toUtc(),
            attempts: 1,
            lastError: failureCode,
          )
        : existing.recordAttempt(failureCode: failureCode);
    await _persist();
  }

  /// Drops [tokenId] — only ever called once the server has confirmed it.
  static Future<void> confirmRevoked(String tokenId) async {
    final id = tokenId.trim();
    if (id.isEmpty) return;
    await ensureLoaded();
    _confirmed.add(id);
    _pending.remove(id);
    await _persist();
  }

  /// Reads, merges, then writes as one critical section.
  static Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final written = await prefs.updateMap(prefsKey, _mergeInto);
    _adopt(written);
  }

  static Map<String, dynamic> _mergeInto(Map<String, dynamic>? current) {
    final byId = <String, PendingConsentRevocation>{};
    for (final stored in _decode(current)) {
      if (_confirmed.contains(stored.tokenId)) continue;
      byId[stored.tokenId] = stored;
    }
    for (final entry in _pending.values) {
      final stored = byId[entry.tokenId];
      byId[entry.tokenId] = stored == null ? entry : entry.mergeWith(stored);
    }
    return {
      'entries': byId.values.map((entry) => entry.toJson()).toList(),
    };
  }

  static void _adopt(Map<String, dynamic>? raw) {
    for (final entry in _decode(raw)) {
      if (_confirmed.contains(entry.tokenId)) continue;
      final mine = _pending[entry.tokenId];
      _pending[entry.tokenId] = mine == null ? entry : mine.mergeWith(entry);
    }
  }

  static List<PendingConsentRevocation> _decode(Map<String, dynamic>? raw) {
    final rows = raw?['entries'];
    if (rows is! List) return const [];
    final decoded = <PendingConsentRevocation>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final entry = PendingConsentRevocation.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (entry != null) decoded.add(entry);
    }
    return decoded;
  }

  /// Drops the in-memory view without touching what is on disk, so a test can
  /// assert that a queued revocation survives an app restart.
  @visibleForTesting
  static void debugForgetLoadedState() {
    _pending.clear();
    _confirmed.clear();
    _loaded = false;
  }

  static Future<void> resetForTest() async {
    _pending.clear();
    _confirmed.clear();
    _loaded = false;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.writeJsonMap(prefsKey, {});
    }
    debugPrefsOverride = null;
  }
}

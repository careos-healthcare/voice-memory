import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/pending_consent_revocation_store.dart';
import 'package:flutter/foundation.dart';

/// Mirrors a local consent revocation to the server, or queues it until it can.
///
/// Every caller reaches this *after* the local revocation has already taken
/// effect, so nothing here is allowed to throw or to block that effect. When
/// the backend is not configured, or the app is running without a bound
/// provider container (widget tests, background isolates), the coordinator
/// degrades to queue-only: the revocation is recorded as owed and retried the
/// next time connectivity or a grants reload triggers a flush.
class ServerConsentRevocationCoordinator {
  ServerConsentRevocationCoordinator({ConsentRevocationApiClient? api})
    : _injectedApi = api;

  static final ServerConsentRevocationCoordinator _shared =
      ServerConsentRevocationCoordinator();

  static ServerConsentRevocationCoordinator? _override;

  /// Shared coordinator used by the revoke paths that have no injection point.
  static ServerConsentRevocationCoordinator get instance =>
      _override ?? _shared;

  @visibleForTesting
  static set instance(ServerConsentRevocationCoordinator value) =>
      _override = value;

  @visibleForTesting
  static void resetForTest() {
    _override = null;
    _shared._ownershipProofs.clear();
  }

  final ConsentRevocationApiClient? _injectedApi;

  /// Signed tokens offered to the server as an ownership-proof fallback for
  /// grants issued before it kept an issuance registry.
  ///
  /// Process-lifetime only, on purpose: persisting a token the user just
  /// revoked would leave a replayable copy on disk. A retry after restart
  /// simply omits the field, which the server accepts.
  final Map<String, Map<String, dynamic>> _ownershipProofs = {};

  ConsentRevocationApiClient? get _api {
    final injected = _injectedApi;
    if (injected != null) return injected;
    final container = boundAppProviderContainer;
    if (container == null) return null;
    try {
      return container.read(caregiverConsentApiClientProvider);
    } on Object {
      // ignore: silent_catch_audit — provider not overridden in this container;
      // the revocation stays queued and is retried on the next flush.
      return null;
    }
  }

  /// Attempts the server revoke, queueing it when it is not confirmed.
  ///
  /// Returns whether the server confirmed. Never throws.
  Future<bool> revokeOnServer({
    required String tokenId,
    required ConsentRevocationDomain domain,
    Map<String, dynamic>? token,
  }) async {
    final id = tokenId.trim();
    if (id.isEmpty) return false;
    if (token != null) _ownershipProofs[id] = token;

    final outcome = await _attempt(id, domain);
    if (outcome.confirmed) {
      await PendingConsentRevocationStore.confirmRevoked(id);
      return true;
    }
    await PendingConsentRevocationStore.enqueue(
      tokenId: id,
      domain: domain,
      failureCode: outcome.failureCode,
    );
    return false;
  }

  /// Retries every queued revocation, removing only the confirmed ones.
  ///
  /// Entries the server rejected permanently are skipped rather than retried,
  /// but stay in the queue so the unfinished revocation remains visible.
  Future<void> flushPending() async {
    await PendingConsentRevocationStore.ensureLoaded();
    final queued = PendingConsentRevocationStore.entries;
    if (queued.isEmpty) return;
    if (_api == null) return;

    for (final entry in queued) {
      if (entry.isPermanentlyRejected) continue;
      final outcome = await _attempt(entry.tokenId, entry.domain);
      if (outcome.confirmed) {
        await PendingConsentRevocationStore.confirmRevoked(entry.tokenId);
        _ownershipProofs.remove(entry.tokenId);
        continue;
      }
      await PendingConsentRevocationStore.enqueue(
        tokenId: entry.tokenId,
        domain: entry.domain,
        failureCode: outcome.failureCode,
      );
    }
  }

  Future<_RevocationAttempt> _attempt(
    String tokenId,
    ConsentRevocationDomain domain,
  ) async {
    final api = _api;
    if (api == null) {
      return const _RevocationAttempt(
        confirmed: false,
        failureCode: ConsentRevocationFailureCode.backendNotConfigured,
      );
    }

    final ApiResult<ConsentRevocationConfirmation> result;
    try {
      result = await api.revokeConsent(
        domain: domain,
        tokenId: tokenId,
        token: _ownershipProofs[tokenId],
      );
    } on Object {
      // ignore: silent_catch_audit — the local revocation already stands; a
      // throwing client must not surface here, only leave the entry queued.
      return const _RevocationAttempt(
        confirmed: false,
        failureCode: ConsentRevocationFailureCode.network,
      );
    }

    return switch (result) {
      ApiSuccess(:final value) => value.isConfirmed
          ? const _RevocationAttempt(confirmed: true)
          : const _RevocationAttempt(
              confirmed: false,
              failureCode: ConsentRevocationFailureCode.notConfirmed,
            ),
      ApiFailureResult(:final failure) => _RevocationAttempt(
        confirmed: false,
        failureCode: _failureCodeFor(failure),
      ),
    };
  }

  /// Maps a transport failure onto the retry policy.
  ///
  /// `403` and `400` are permanent; everything else — including `401`, which a
  /// later sign-in can resolve — stays retryable.
  static String _failureCodeFor(ApiFailure failure) {
    if (failure is ApiFailureBackendNotConfigured) {
      return ConsentRevocationFailureCode.backendNotConfigured;
    }
    if (failure is ApiFailureAuthRequired) {
      return ConsentRevocationFailureCode.authRequired;
    }
    if (failure is ApiFailureOffline) {
      return ConsentRevocationFailureCode.network;
    }
    final status = failure.statusCode;
    if (status == 403) return ConsentRevocationFailureCode.forbidden;
    if (status == 400) return ConsentRevocationFailureCode.invalidRequest;
    if (status != null && status >= 500) {
      return ConsentRevocationFailureCode.serverUnavailable;
    }
    return ConsentRevocationFailureCode.network;
  }
}

class _RevocationAttempt {
  const _RevocationAttempt({required this.confirmed, this.failureCode});

  final bool confirmed;
  final String? failureCode;
}

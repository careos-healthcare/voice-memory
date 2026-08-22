import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/data/network/consent_renewal_api_client.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_renewal_outcome.dart';
import 'package:flutter/foundation.dart';

/// A renewal attempt, split into the part that may be stored and the part that
/// may not.
///
/// [outcome] is the persistable half: booleans, a grant id, a timestamp and a
/// code from a closed set. [successorToken] is the signed credential the server
/// returned, handed to the caller to write into its own token storage and
/// deliberately kept out of [outcome], which surfaces are free to log or keep
/// in plain preferences.
class ConsentRenewalAttempt {
  const ConsentRenewalAttempt({required this.outcome, this.successorToken});

  factory ConsentRenewalAttempt.refused(String failureCode) =>
      ConsentRenewalAttempt(
        outcome: ConsentRenewalOutcome.refused(failureCode),
      );

  final ConsentRenewalOutcome outcome;
  final Map<String, dynamic>? successorToken;
}

/// Carries an owner's renewal request to the server, once.
///
/// Sibling to `ServerConsentRevocationCoordinator`, and deliberately missing
/// the thing that makes that class useful. Revocation has a pending queue: the
/// user has already withdrawn access locally, and the server call is a debt the
/// device owes and should keep trying to settle. Renewal has no queue and no
/// retry, because the debt runs the other way. A renewal replayed from a queue
/// would extend access at a moment nobody was asked about, which is the
/// scheduled extension a 7-day window exists to rule out. A renewal that does
/// not land is simply reported as not done, and the owner can ask again.
///
/// Never throws. A surface that offers renewal should stay usable when the
/// network does not.
class ServerConsentRenewalCoordinator {
  ServerConsentRenewalCoordinator({ConsentRenewalApiClient? api})
    : _injectedApi = api;

  static final ServerConsentRenewalCoordinator _shared =
      ServerConsentRenewalCoordinator();

  static ServerConsentRenewalCoordinator? _override;

  static ServerConsentRenewalCoordinator get instance =>
      _override ?? _shared;

  @visibleForTesting
  static set instance(ServerConsentRenewalCoordinator value) =>
      _override = value;

  @visibleForTesting
  static void resetForTest() => _override = null;

  final ConsentRenewalApiClient? _injectedApi;

  /// Resolves the renewal seam from the bound container.
  ///
  /// The consent provider is typed as `CaregiverConsentApiClient`, which does
  /// not promise renewal; the production HTTP client implements both. A client
  /// that does not leaves renewal unavailable rather than partly wired, which
  /// is the direction that ends with less access rather than more.
  ConsentRenewalApiClient? get _api {
    final injected = _injectedApi;
    if (injected != null) return injected;
    final container = boundAppProviderContainer;
    if (container == null) return null;
    try {
      final client = container.read(caregiverConsentApiClientProvider);
      if (client is! ConsentRenewalApiClient) return null;
      return client as ConsentRenewalApiClient;
    } on Object {
      // ignore: silent_catch_audit — provider not overridden in this container;
      // renewal is reported as unavailable and the grant is left as it is.
      return null;
    }
  }

  /// Asks the server to replace [token] with a fresh caregiver grant.
  ///
  /// [ownerConfirmedAt] is when the archive owner confirmed on this device.
  /// The server rejects one that is more than a few minutes old, so a caller
  /// must pass the moment of the confirmation rather than the moment it got
  /// around to making the call.
  Future<ConsentRenewalAttempt> renewOnServer({
    required String tokenId,
    required Map<String, dynamic> token,
    required DateTime ownerConfirmedAt,
  }) async {
    final id = tokenId.trim();
    if (id.isEmpty) {
      return const ConsentRenewalAttempt(
        outcome: ConsentRenewalOutcome.notAttempted,
      );
    }

    final api = _api;
    if (api == null) {
      return ConsentRenewalAttempt.refused(
        ConsentRenewalFailureCode.backendNotConfigured,
      );
    }

    final ApiResult<ConsentRenewalConfirmation> result;
    try {
      result = await api.renewCaregiverConsent(
        tokenId: id,
        token: token,
        ownerConfirmedAt: ownerConfirmedAt,
      );
    } on Object {
      // ignore: silent_catch_audit — a throwing client must not surface here;
      // the existing grant is untouched and the owner can ask again.
      return ConsentRenewalAttempt.refused(ConsentRenewalFailureCode.network);
    }

    return switch (result) {
      ApiSuccess(:final value) => _fromConfirmation(value),
      ApiFailureResult(:final failure) => ConsentRenewalAttempt.refused(
        failureCodeFor(failure),
      ),
    };
  }

  static ConsentRenewalAttempt _fromConfirmation(
    ConsentRenewalConfirmation confirmation,
  ) {
    if (!confirmation.isConfirmed) {
      return ConsentRenewalAttempt.refused(
        ConsentRenewalFailureCode.notConfirmed,
      );
    }
    return ConsentRenewalAttempt(
      outcome: ConsentRenewalOutcome(
        renewed: true,
        previousGrantEnded: confirmation.previousRevokedAt != null,
        newGrantId: confirmation.token.tokenId,
        newExpiresAt: confirmation.token.expiresAt,
      ),
      successorToken: confirmation.token.toJson(),
    );
  }

  /// Maps a transport failure onto the closed code set.
  ///
  /// Nothing here schedules a retry — the codes only tell a surface what it
  /// may honestly say. The server's own code is consulted before the status,
  /// because a window that has run out and a grant that was withdrawn both
  /// answer `409` and lead somewhere different: the first is a lapsed
  /// arrangement the owner can start again, the second is a decision already
  /// taken. The server string is read here and discarded; only a code from
  /// `ConsentRenewalFailureCode` leaves this method.
  @visibleForTesting
  static String failureCodeFor(ApiFailure failure) {
    if (failure is ApiFailureBackendNotConfigured) {
      return ConsentRenewalFailureCode.backendNotConfigured;
    }
    if (failure is ApiFailureAuthRequired) {
      return ConsentRenewalFailureCode.authRequired;
    }
    if (failure is ApiFailureOffline) {
      return ConsentRenewalFailureCode.network;
    }

    switch (failure.code) {
      case 'GRANT_EXPIRED':
        return ConsentRenewalFailureCode.grantExpired;
      case 'GRANT_NOT_RENEWABLE':
        return ConsentRenewalFailureCode.notRenewable;
      case 'OWNER_CONFIRMATION_REQUIRED':
        return ConsentRenewalFailureCode.confirmationRequired;
      case 'CONSENT_RENEWAL_FAILED':
        return ConsentRenewalFailureCode.serverUnavailable;
      case 'FORBIDDEN':
        return ConsentRenewalFailureCode.notGrantOwner;
    }

    final status = failure.statusCode;
    if (status == 403) return ConsentRenewalFailureCode.notGrantOwner;
    if (status == 409) return ConsentRenewalFailureCode.notRenewable;
    if (status == 400) return ConsentRenewalFailureCode.confirmationRequired;
    if (status != null && status >= 500) {
      return ConsentRenewalFailureCode.serverUnavailable;
    }
    return ConsentRenewalFailureCode.network;
  }
}

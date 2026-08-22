import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart';
import 'package:archiveme_mobile/data/network/coach_consent_api_client.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Coach-specific consent policy — isolated from caregiver monitoring secrets.
abstract final class CoachModeConfigPolicy {
  CoachModeConfigPolicy._();

  static const int currentPolicyVersion = 1;
}

enum CoachConsentTokenSource {
  local,
  server,
}

/// Verifies [CoachConsentToken] signatures before coach dashboard unlocks.
class ClientConsentVerificationService {
  ClientConsentVerificationService({
    FlutterSecureStorage? secureStorage,
    this._signingSecretOverride,
    this._consentApi,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const _secretStorageKey = 'coach_client_consent_hmac_secret_v1';

  final FlutterSecureStorage _secureStorage;
  final String? _signingSecretOverride;
  final CoachConsentApiClient? _consentApi;
  final Uuid _uuid = const Uuid();

  CoachConsentTokenSource _lastIssuanceSource = CoachConsentTokenSource.local;

  CoachConsentTokenSource get lastIssuanceSource => _lastIssuanceSource;

  Future<CoachTokenVerificationResult> verify(
    CoachConsentToken token, {
    DateTime? now,
    CoachConsentTokenSource source = CoachConsentTokenSource.local,
  }) async {
    if (source == CoachConsentTokenSource.server && _consentApi != null) {
      return _verifyViaServer(token);
    }
    final clock = (now ?? DateTime.now()).toUtc();

    if (token.policyVersion != CoachModeConfigPolicy.currentPolicyVersion) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Unsupported coach consent policy version',
      );
    }

    if (token.tokenId.isEmpty ||
        token.relationshipId.isEmpty ||
        token.clientAccountId.isEmpty ||
        token.coachId.isEmpty ||
        token.clientAffirmationHash.isEmpty) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Incomplete coach consent token',
      );
    }

    await ConsentRevocationStore.ensureLoaded();
    if (ConsentRevocationStore.isRevoked(token.tokenId)) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Consent token revoked',
      );
    }

    if (!clock.isBefore(token.expiresAt)) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Coach consent token expired',
      );
    }

    if (clock.isBefore(token.issuedAt)) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Coach consent token not yet valid',
      );
    }

    final expected = await _signPayload(_canonicalPayload(token));
    if (!_constantTimeEquals(expected, token.signature)) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Invalid coach consent signature',
      );
    }

    final session = CoachSession(
      sessionId: _uuid.v4(),
      mode: AppMode.professionalCoach,
      coachId: token.coachId,
      clientAccountId: token.clientAccountId,
      relationshipId: token.relationshipId,
      permissions: token.permissions,
      tokenId: token.tokenId,
      startedAt: clock,
      expiresAt: token.expiresAt,
      validatedAt: clock,
    );

    return CoachTokenVerificationResult(valid: true, session: session);
  }

  Future<CoachConsentToken> issueToken({
    required String relationshipId,
    required String clientAccountId,
    required String coachId,
    required CoachSharingPermissions permissions,
    required String clientAffirmationHash,
    Duration ttl = const Duration(days: 90),
    DateTime? now,
    bool preferServerIssuance = false,
  }) async {
    if (preferServerIssuance &&
        AppConfig.isBackendConfigured &&
        _consentApi != null) {
      final result = await _consentApi.issueToken(
        relationshipId: relationshipId,
        coachId: coachId,
        permissions: permissions,
        clientAffirmationHash: clientAffirmationHash,
      );
      if (result case ApiSuccess(:final value)) {
        _lastIssuanceSource = CoachConsentTokenSource.server;
        return value;
      }
    }

    _lastIssuanceSource = CoachConsentTokenSource.local;
    final clock = (now ?? DateTime.now()).toUtc();
    final tokenId = _uuid.v4();
    final draft = CoachConsentToken(
      tokenId: tokenId,
      relationshipId: relationshipId,
      clientAccountId: clientAccountId,
      coachId: coachId,
      permissions: permissions,
      issuedAt: clock,
      expiresAt: clock.add(ttl),
      policyVersion: CoachModeConfigPolicy.currentPolicyVersion,
      clientAffirmationHash: clientAffirmationHash,
      signature: '',
    );
    final signature = await _signPayload(_canonicalPayload(draft));
    return CoachConsentToken(
      tokenId: tokenId,
      relationshipId: relationshipId,
      clientAccountId: clientAccountId,
      coachId: coachId,
      permissions: permissions,
      issuedAt: clock,
      expiresAt: clock.add(ttl),
      policyVersion: CoachModeConfigPolicy.currentPolicyVersion,
      clientAffirmationHash: clientAffirmationHash,
      signature: signature,
    );
  }

  static String hashClientAffirmation(String affirmation) {
    return sha256.convert(utf8.encode(affirmation.trim())).toString();
  }

  Map<String, Object?> _canonicalPayload(CoachConsentToken token) => {
        'tokenId': token.tokenId,
        'relationshipId': token.relationshipId,
        'clientAccountId': token.clientAccountId,
        'coachId': token.coachId,
        'permissions': token.permissions.toJson(),
        'issuedAt': token.issuedAt.toUtc().toIso8601String(),
        'expiresAt': token.expiresAt.toUtc().toIso8601String(),
        'policyVersion': token.policyVersion,
        'clientAffirmationHash': token.clientAffirmationHash,
      };

  Future<String> _signPayload(Map<String, Object?> payload) async {
    final secret = await _signingSecret();
    final canonical = jsonEncode(_sortMap(payload));
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert(utf8.encode(canonical)).toString();
  }

  Map<String, Object?> _sortMap(Map<String, Object?> input) {
    final keys = input.keys.toList()..sort();
    final out = <String, Object?>{};
    for (final key in keys) {
      final value = input[key];
      if (value is Map<String, Object?>) {
        out[key] = _sortMap(value);
      } else if (value is Map) {
        out[key] = _sortMap(Map<String, Object?>.from(value.cast<String, Object?>()));
      } else if (value is List) {
        out[key] = List<Object?>.from(value);
      } else {
        out[key] = value;
      }
    }
    return out;
  }

  Future<String> _signingSecret() async {
    final override = _signingSecretOverride;
    if (override != null && override.isNotEmpty) return override;

    final existing = await _secureStorage.read(key: _secretStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _uuid.v4();
    await _secureStorage.write(key: _secretStorageKey, value: generated);
    return generated;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<CoachTokenVerificationResult> _verifyViaServer(
    CoachConsentToken token,
  ) async {
    final api = _consentApi;
    if (api == null) {
      return const CoachTokenVerificationResult(
        valid: false,
        reason: 'Server consent verification unavailable',
      );
    }

    final result = await api.verifyToken(token: token);
    return switch (result) {
      ApiSuccess(:final value) => value,
      ApiFailureResult() => const CoachTokenVerificationResult(
          valid: false,
          reason: 'Server consent verification failed',
        ),
    };
  }
}
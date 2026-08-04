// Public named parameters intentionally avoid private field names.
// ignore_for_file: prefer_initializing_formals

import '../../api/journal_sync_api_client.dart';
import '../../services/analytics/operational_analytics.dart';
import '../archive_ownership/local_archive_identity.dart';
import '../journal/sync/saved_moment_sync_key_store.dart';
import 'sync_recovery_crypto.dart';

final class SyncRecoveryStatus {
  const SyncRecoveryStatus({
    required this.enabled,
    this.envelopeRevision,
    this.updatedAt,
  });

  final bool enabled;
  final int? envelopeRevision;
  final DateTime? updatedAt;
}

/// Coordinates recovery without retaining or transmitting the recovery secret.
final class SyncRecoveryService {
  SyncRecoveryService({
    required JournalSyncApiClient api,
    required SavedMomentSyncKeyStore keyStore,
    required LocalArchiveIdentity Function() identityProvider,
    Future<void> Function(String accountId, String archiveId)?
    adoptRecoveredArchive,
    SyncRecoveryCrypto crypto = const SyncRecoveryCrypto(),
  }) : _api = api,
       _keyStore = keyStore,
       _identityProvider = identityProvider,
       _adoptRecoveredArchive = adoptRecoveredArchive,
       _crypto = crypto;

  final JournalSyncApiClient _api;
  final SavedMomentSyncKeyStore _keyStore;
  final LocalArchiveIdentity Function() _identityProvider;
  final Future<void> Function(String accountId, String archiveId)?
  _adoptRecoveredArchive;
  final SyncRecoveryCrypto _crypto;

  Future<SyncRecoveryStatus> status() async {
    final identity = _requireIdentity();
    final response = await _api.syncRecoveryStatus();
    _assertCurrent(identity);
    return SyncRecoveryStatus(
      enabled: response['enabled'] == true,
      envelopeRevision: (response['envelopeRevision'] as num?)?.toInt(),
      updatedAt: DateTime.tryParse(response['updatedAt']?.toString() ?? ''),
    );
  }

  Future<SyncRecoverySetup> enableOrReplace() =>
      _observeRecovery(_enableOrReplace);

  Future<SyncRecoverySetup> _enableOrReplace() async {
    final identity = _requireIdentity();
    final current = await _api.syncRecoveryFetch();
    _assertCurrent(identity);
    final existing = current['envelope'] is Map
        ? SyncRecoveryEnvelope.fromJson(
            Map<String, dynamic>.from(current['envelope'] as Map),
          )
        : null;
    final lastSeenRevision = await _keyStore.readRecoveryRevision(
      identity.authenticatedSubjectId!,
    );
    final material = await _keyStore.requireKeyMaterial(identity.archiveId);
    final setup = await _crypto.wrap(
      syncKey: material.bytes,
      ownerAccountId: identity.authenticatedSubjectId!,
      ownerArchiveId: identity.archiveId,
      keyEpoch: material.epoch,
      envelopeRevision:
          (existing?.envelopeRevision ?? lastSeenRevision ?? 0) + 1,
      createdAt: existing?.createdAt,
    );
    try {
      await _api.syncRecoveryUpsert(setup.envelope.toJson());
      _assertCurrent(identity);
      await _keyStore.recordRecoveryRevision(
        identity.authenticatedSubjectId!,
        setup.envelope.envelopeRevision,
      );
      return setup;
    } finally {
      material.bytes.fillRange(0, material.bytes.length, 0);
    }
  }

  /// Restores the existing random sync data key onto this device.
  Future<void> recover(String recoverySecret) =>
      _observeRecovery(() => _recover(recoverySecret));

  Future<void> _recover(String recoverySecret) async {
    final identity = _requireIdentity();
    final response = await _api.syncRecoveryFetch();
    _assertAccountCurrent(identity);
    if (response['envelope'] is! Map) {
      throw const SyncRecoveryException('recovery_not_enabled');
    }
    final envelope = SyncRecoveryEnvelope.fromJson(
      Map<String, dynamic>.from(response['envelope'] as Map),
    );
    final minimumRevision = await _keyStore.readRecoveryRevision(
      identity.authenticatedSubjectId!,
    );
    final key = await _crypto.unwrap(
      envelope: envelope,
      secret: recoverySecret,
      expectedAccountId: identity.authenticatedSubjectId!,
      expectedArchiveId: envelope.ownerArchiveId,
      expectedKeyEpoch: envelope.keyEpoch,
      minimumEnvelopeRevision: minimumRevision,
    );
    try {
      _assertAccountCurrent(identity);
      await _keyStore.installRecoveredKey(
        envelope.ownerArchiveId,
        key,
        epoch: envelope.keyEpoch,
      );
      if (envelope.ownerArchiveId != identity.archiveId) {
        final adopter = _adoptRecoveredArchive;
        if (adopter == null) {
          await _keyStore.deleteKey(envelope.ownerArchiveId);
          throw const SyncRecoveryException('archive_adoption_unavailable');
        }
        await adopter(
          identity.authenticatedSubjectId!,
          envelope.ownerArchiveId,
        );
        try {
          await _keyStore.deleteKey(identity.archiveId);
        } on Object {
          // The adopted archive is authoritative; an obsolete unreachable key
          // can be removed by the next secure-storage wipe.
        }
      }
      final recoveredIdentity = _identityProvider();
      if (recoveredIdentity.archiveId != envelope.ownerArchiveId ||
          recoveredIdentity.authenticatedSubjectId !=
              identity.authenticatedSubjectId) {
        throw const SyncRecoveryException('account_scope_changed');
      }
      await _keyStore.recordRecoveryRevision(
        identity.authenticatedSubjectId!,
        envelope.envelopeRevision,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<bool> verify(String recoverySecret) =>
      _observeRecovery(() => _verify(recoverySecret));

  Future<bool> _verify(String recoverySecret) async {
    final identity = _requireIdentity();
    final response = await _api.syncRecoveryFetch();
    _assertCurrent(identity);
    if (response['envelope'] is! Map) return false;
    final envelope = SyncRecoveryEnvelope.fromJson(
      Map<String, dynamic>.from(response['envelope'] as Map),
    );
    final minimumRevision = await _keyStore.readRecoveryRevision(
      identity.authenticatedSubjectId!,
    );
    final recovered = await _crypto.unwrap(
      envelope: envelope,
      secret: recoverySecret,
      expectedAccountId: identity.authenticatedSubjectId!,
      expectedArchiveId: identity.archiveId,
      expectedKeyEpoch: envelope.keyEpoch,
      minimumEnvelopeRevision: minimumRevision,
    );
    final local = await _keyStore.readKey(identity.archiveId);
    try {
      if (local == null || local.length != recovered.length) return false;
      var difference = 0;
      for (var i = 0; i < local.length; i++) {
        difference |= local[i] ^ recovered[i];
      }
      return difference == 0;
    } finally {
      local?.fillRange(0, local.length, 0);
      recovered.fillRange(0, recovered.length, 0);
    }
  }

  Future<void> disable() => _observeRecovery(_disable);

  Future<void> _disable() async {
    final identity = _requireIdentity();
    await _api.syncRecoveryDelete();
    _assertCurrent(identity);
  }

  Future<T> _observeRecovery<T>(Future<T> Function() operation) async {
    await SyncRecoveryOperationalAnalytics.recoveryStarted();
    try {
      final result = await operation();
      await SyncRecoveryOperationalAnalytics.recoveryCompleted();
      return result;
    } on Object catch (error) {
      await SyncRecoveryOperationalAnalytics.recoveryFailed(
        _failureCategory(error),
      );
      rethrow;
    }
  }

  static OperationalFailureCategory _failureCategory(Object error) {
    if (error is SyncRecoveryException) {
      final code = error.code;
      if (code == 'authentication_required' ||
          code == 'account_scope_changed') {
        return OperationalFailureCategory.authentication;
      }
      return OperationalFailureCategory.validation;
    }
    return OperationalFailureCategory.providerUnavailable;
  }

  LocalArchiveIdentity _requireIdentity() {
    final identity = _identityProvider();
    if (!identity.maySync ||
        identity.authenticatedSubjectId?.trim().isEmpty != false) {
      throw const SyncRecoveryException('authentication_required');
    }
    return identity;
  }

  void _assertCurrent(LocalArchiveIdentity expected) {
    final current = _identityProvider();
    if (!current.maySync ||
        current.archiveId != expected.archiveId ||
        current.authenticatedSubjectId != expected.authenticatedSubjectId) {
      throw const SyncRecoveryException('account_scope_changed');
    }
  }

  void _assertAccountCurrent(LocalArchiveIdentity expected) {
    final current = _identityProvider();
    if (!current.maySync ||
        current.authenticatedSubjectId != expected.authenticatedSubjectId) {
      throw const SyncRecoveryException('account_scope_changed');
    }
  }
}

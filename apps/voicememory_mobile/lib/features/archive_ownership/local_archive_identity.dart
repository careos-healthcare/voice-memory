import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../storage/secure_storage.dart';

enum LocalArchiveOwnerKind { guest, authenticated, legacyUnclaimed }

enum LocalArchiveOwnershipState {
  active,
  locked,
  awaitingDecision,
  migrating,
  migrationFailed,
}

final class LocalArchiveIdentity {
  const LocalArchiveIdentity({
    required this.archiveId,
    required this.ownerKind,
    required this.ownershipState,
    this.authenticatedSubjectId,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  final String archiveId;
  final LocalArchiveOwnerKind ownerKind;
  final String? authenticatedSubjectId;
  final LocalArchiveOwnershipState ownershipState;
  final int schemaVersion;

  bool get mayRender =>
      ownershipState == LocalArchiveOwnershipState.active ||
      (ownerKind == LocalArchiveOwnerKind.legacyUnclaimed &&
          ownershipState == LocalArchiveOwnershipState.awaitingDecision);

  bool get maySync =>
      ownerKind == LocalArchiveOwnerKind.authenticated &&
      ownershipState == LocalArchiveOwnershipState.active &&
      authenticatedSubjectId?.trim().isNotEmpty == true;

  Map<String, Object?> toJson() => {
    'archiveId': archiveId,
    'ownerKind': ownerKind.name,
    'authenticatedSubjectId': authenticatedSubjectId,
    'ownershipState': ownershipState.name,
    'schemaVersion': schemaVersion,
  };

  static LocalArchiveIdentity? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final archiveId = json['archiveId']?.toString().trim() ?? '';
    final ownerKind = LocalArchiveOwnerKind.values
        .where((item) => item.name == json['ownerKind'])
        .firstOrNull;
    final ownershipState = LocalArchiveOwnershipState.values
        .where((item) => item.name == json['ownershipState'])
        .firstOrNull;
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (archiveId.isEmpty ||
        ownerKind == null ||
        ownershipState == null ||
        schemaVersion != currentSchemaVersion) {
      return null;
    }
    return LocalArchiveIdentity(
      archiveId: archiveId,
      ownerKind: ownerKind,
      authenticatedSubjectId: json['authenticatedSubjectId']?.toString(),
      ownershipState: ownershipState,
      schemaVersion: schemaVersion!,
    );
  }
}

final class LocalArchiveIdentityStore {
  LocalArchiveIdentityStore(this._secure, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _guestKey = 'local_archive_identity_guest_v1';
  static const _legacyKey = 'local_archive_identity_legacy_v1';

  final SecureStorageService _secure;
  final Uuid _uuid;

  Future<LocalArchiveIdentity> resolve({
    required String? authenticatedSubjectId,
    required bool legacyOwnerlessArchiveExists,
  }) async {
    final subject = authenticatedSubjectId?.trim();
    if (subject?.isNotEmpty == true) {
      return _authenticated(subject!);
    }
    if (legacyOwnerlessArchiveExists) {
      return _readOrCreate(
        _legacyKey,
        LocalArchiveOwnerKind.legacyUnclaimed,
        LocalArchiveOwnershipState.awaitingDecision,
      );
    }
    return _readOrCreate(
      _guestKey,
      LocalArchiveOwnerKind.guest,
      LocalArchiveOwnershipState.active,
    );
  }

  /// Archives that exist on this device but belong to no account yet.
  ///
  /// Only guest and legacy archives are ever returned. Another authenticated
  /// account's archive is deliberately unreachable from here, so it can never
  /// be offered to the account currently signed in.
  Future<List<LocalArchiveIdentity>> unclaimedArchives() async {
    final found = <LocalArchiveIdentity>[];
    for (final key in const [_guestKey, _legacyKey]) {
      final identity = await _read(key);
      if (identity == null) continue;
      if (identity.ownerKind == LocalArchiveOwnerKind.guest ||
          identity.ownerKind == LocalArchiveOwnerKind.legacyUnclaimed) {
        found.add(identity);
      }
    }
    return List.unmodifiable(found);
  }

  Future<LocalArchiveIdentity> adoptAuthenticatedArchive({
    required String authenticatedSubjectId,
    required String archiveId,
  }) async {
    final subject = authenticatedSubjectId.trim();
    final archive = archiveId.trim();
    if (subject.isEmpty ||
        archive.length < 8 ||
        archive.length > 200 ||
        !archive.startsWith('account_')) {
      throw StateError('Recovered archive identity is invalid.');
    }
    final identity = LocalArchiveIdentity(
      archiveId: archive,
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: subject,
      ownershipState: LocalArchiveOwnershipState.active,
    );
    final subjectHash = sha256.convert(utf8.encode(subject)).toString();
    await _write('local_archive_identity_account_$subjectHash', identity);
    return identity;
  }

  Future<LocalArchiveIdentity> _authenticated(String subject) async {
    final subjectHash = sha256.convert(utf8.encode(subject)).toString();
    final key = 'local_archive_identity_account_$subjectHash';
    final existing = await _read(key);
    if (existing != null &&
        existing.ownerKind == LocalArchiveOwnerKind.authenticated &&
        existing.authenticatedSubjectId == subject) {
      return existing;
    }
    final identity = LocalArchiveIdentity(
      archiveId: 'account_${_uuid.v4()}',
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: subject,
      ownershipState: LocalArchiveOwnershipState.active,
    );
    await _write(key, identity);
    return identity;
  }

  Future<LocalArchiveIdentity> _readOrCreate(
    String key,
    LocalArchiveOwnerKind ownerKind,
    LocalArchiveOwnershipState ownershipState,
  ) async {
    final existing = await _read(key);
    if (existing != null && existing.ownerKind == ownerKind) return existing;
    final identity = LocalArchiveIdentity(
      archiveId: '${ownerKind.name}_${_uuid.v4()}',
      ownerKind: ownerKind,
      ownershipState: ownershipState,
    );
    await _write(key, identity);
    return identity;
  }

  Future<LocalArchiveIdentity?> _read(String key) async {
    final raw = await _secure.read(key);
    if (raw == null) return null;
    try {
      return LocalArchiveIdentity.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, LocalArchiveIdentity identity) =>
      _secure.write(key, jsonEncode(identity.toJson()));
}

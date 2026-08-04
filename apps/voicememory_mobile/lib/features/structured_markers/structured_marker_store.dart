import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'structured_markers.dart';

/// Durable, archive-scoped home for the optional ten-second check.
///
/// Markers live beside the archive's own journal and never touch
/// `JournalEntry`, so a moment saves whether or not markers exist and the
/// journal schema stays owned by the journal. Every row carries its owning
/// archive, and a read never returns another archive's markers.
class StructuredMarkerStore {
  StructuredMarkerStore({
    required File file,
    required PrivateDataEncryptionKeyStore keyStore,
    required this.archiveId,
  }) : assert(archiveId != '', 'A marker store must belong to an archive.'),
       _storage = EncryptedJsonFileStore(file: file, keyStore: keyStore);

  static const storeVersion = 1;
  static const fileName = 'structured_markers.enc';

  final EncryptedJsonFileStore _storage;
  final String archiveId;
  Future<void> _pending = Future.value();

  File get encryptedFile => _storage.file;

  /// Every marker set this archive holds, keyed by entry id.
  ///
  /// This is the read API export and deletion should use: it returns only the
  /// current archive's markers, and the map is safe to iterate alongside the
  /// journal entries of the same archive.
  Future<Map<String, StructuredMarkers>> forArchive() =>
      _serialized(_readOwned);

  Future<StructuredMarkers?> read(String entryId) async =>
      (await forArchive())[entryId];

  /// Stores [markers]. An empty marker set is stored as a removal, so a reader
  /// clearing every answer leaves nothing behind.
  Future<void> save(StructuredMarkers markers) => _serialized(() async {
    if (markers.entryId.isEmpty) return;
    final current = await _readOwned();
    if (markers.isEmpty) {
      current.remove(markers.entryId);
    } else {
      current[markers.entryId] = markers;
    }
    await _writeOwned(current);
  });

  Future<void> remove(String entryId) => _serialized(() async {
    final current = await _readOwned();
    if (current.remove(entryId) == null) return;
    await _writeOwned(current);
  });

  /// Drops every marker in this archive. Used by archive deletion.
  Future<void> clear() =>
      _serialized(() => _writeOwned(<String, StructuredMarkers>{}));

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _readEnvelope() async {
    final raw = await _storage.readJson();
    if (raw is! Map) return {};
    final json = Map<String, dynamic>.from(raw);
    if (json['storeVersion'] != storeVersion) return {};
    final archives = json['archives'];
    return archives is Map ? Map<String, dynamic>.from(archives) : {};
  }

  Future<Map<String, StructuredMarkers>> _readOwned() async {
    final archives = await _readEnvelope();
    final mine = archives[archiveId];
    if (mine is! Map) return {};
    final markers = Map<String, dynamic>.from(mine)['markers'];
    if (markers is! List) return {};
    return {
      for (final marker
          in markers
              .map(StructuredMarkers.fromJson)
              .whereType<StructuredMarkers>()
              .where((marker) => marker.isNotEmpty))
        marker.entryId: marker,
    };
  }

  Future<void> _writeOwned(Map<String, StructuredMarkers> markers) async {
    final archives = await _readEnvelope();
    final ordered = markers.keys.toList()..sort();
    archives[archiveId] = {
      'markers': [for (final entryId in ordered) markers[entryId]!.toJson()],
    };
    await _storage.writeJson({
      'storeVersion': storeVersion,
      'archives': archives,
    });
  }
}

/// Resolves the current archive's marker store, so every caller reads from
/// exactly one place.
///
/// Export and deletion should go through [forArchive] and [clearAll]; both
/// no-op safely before services are initialised.
abstract final class StructuredMarkerRepository {
  static StructuredMarkerStore? _store;
  static String? _storeArchiveId;

  static StructuredMarkerStore? storeOrNull() {
    if (!AppServices.isInitialized) return null;
    final journal = AppServices.instance.journalStore;
    final archiveId = journal.ownerArchiveId;
    if (_store != null && _storeArchiveId == archiveId) return _store;
    _store = StructuredMarkerStore(
      file: File(
        '${journal.file.parent.path}/${StructuredMarkerStore.fileName}',
      ),
      keyStore: _keyStore(),
      archiveId: archiveId,
    );
    _storeArchiveId = archiveId;
    return _store;
  }

  /// Every marker set in the current archive, keyed by entry id.
  static Future<Map<String, StructuredMarkers>> forArchive() async =>
      await storeOrNull()?.forArchive() ?? const {};

  static Future<StructuredMarkers?> read(String entryId) async =>
      storeOrNull()?.read(entryId);

  static Future<void> save(StructuredMarkers markers) async =>
      storeOrNull()?.save(markers);

  static Future<void> remove(String entryId) async =>
      storeOrNull()?.remove(entryId);

  static Future<void> clearAll() async => storeOrNull()?.clear();

  static PrivateDataEncryptionKeyStore _keyStore() =>
      Platform.environment.containsKey('FLUTTER_TEST')
      ? InMemoryPrivateDataEncryptionKeyStore()
      : SecurePrivateDataEncryptionKeyStore(
          secure: AppServices.instance.secureStorage,
        );

  @visibleForTesting
  static void resetForTest() {
    _store = null;
    _storeArchiveId = null;
  }
}

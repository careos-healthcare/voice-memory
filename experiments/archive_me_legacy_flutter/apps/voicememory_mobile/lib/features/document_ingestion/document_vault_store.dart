import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../services/local_storage/encrypted_storage_engine.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'document_models.dart';

/// Encrypted metadata and original document blobs with authenticated AAD.
final class DocumentVaultStore {
  DocumentVaultStore({
    required Directory directory,
    required PrivateDataEncryptionKeyStore keyStore,
    EncryptedStorageEngine? engine,
    DateTime Function()? clock,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _directory = directory,
       // ignore: prefer_initializing_formals
       _keyStore = keyStore,
       _engine = engine ?? EncryptedStorageEngine(),
       _clock = clock ?? DateTime.now;

  final Directory _directory;
  final PrivateDataEncryptionKeyStore _keyStore;
  final EncryptedStorageEngine _engine;
  final DateTime Function() _clock;
  Future<void> _tail = Future<void>.value();

  File get _metadataFile => File('${_directory.path}/metadata.vault');

  Future<void> put({
    required StoredDocumentMetadata metadata,
    required Uint8List originalBytes,
  }) => _serialized(() async {
    _validateId(metadata.id);
    if (metadata.isDeleted || metadata.byteLength != originalBytes.length) {
      throw ArgumentError('Document metadata does not match the original.');
    }
    final blob = _blobFile(metadata.id);
    final copy = Uint8List.fromList(originalBytes);
    try {
      await _withKey((key) {
        return _engine.writeFile(
          blob,
          copy,
          keyBytes: key,
          associatedData: _blobAad(metadata.id),
        );
      });
      final rows = await _readMetadata();
      rows[metadata.id] = metadata;
      await _writeMetadata(rows.values);
    } on Object {
      if (await blob.exists()) await blob.delete();
      rethrow;
    } finally {
      _wipe(copy);
    }
  });

  Future<List<StoredDocumentMetadata>> list({bool includeTombstones = false}) =>
      _serialized(() async {
        final rows =
            (await _readMetadata()).values
                .where((row) => includeTombstones || !row.isDeleted)
                .toList()
              ..sort((left, right) {
                final byDate = right.createdAt.compareTo(left.createdAt);
                return byDate != 0 ? byDate : left.id.compareTo(right.id);
              });
        return List.unmodifiable(rows);
      });

  Future<void> putRecord(StoredDocumentRecord record) => _serialized(() async {
    _validateId(record.metadata.id);
    final clear = Uint8List.fromList(utf8.encode(jsonEncode(record.toJson())));
    try {
      await _withKey(
        (key) => _engine.writeFile(
          _recordFile(record.metadata.id),
          clear,
          keyBytes: key,
          associatedData: _recordAad(record.metadata.id),
        ),
      );
    } finally {
      _wipe(clear);
    }
  });

  Future<StoredDocumentRecord?> readRecord(String id) => _serialized(() async {
    _validateId(id);
    final file = _recordFile(id);
    if (!await file.exists()) return null;
    return _withKey((key) async {
      Uint8List? clear;
      try {
        clear = await _engine.readFile(
          file,
          keyBytes: key,
          associatedData: _recordAad(id),
        );
        return StoredDocumentRecord.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
        );
      } finally {
        _wipe(clear);
      }
    });
  });

  Future<T?> withOriginal<T>(
    String id,
    Future<T> Function(Uint8List bytes) operation,
  ) => _serialized(() async {
    _validateId(id);
    final metadata = (await _readMetadata())[id];
    if (metadata == null || metadata.isDeleted) return null;
    final file = _blobFile(id);
    if (!await file.exists()) return null;
    return _withKey((key) async {
      Uint8List? clear;
      try {
        clear = await _engine.readFile(
          file,
          keyBytes: key,
          associatedData: _blobAad(id),
        );
        return await operation(clear);
      } finally {
        _wipe(clear);
      }
    });
  });

  /// Removes the blob and retains an encrypted deletion tombstone.
  Future<void> delete(String id) => _serialized(() async {
    _validateId(id);
    final rows = await _readMetadata();
    final current = rows[id];
    if (current == null) return;
    final blob = _blobFile(id);
    if (await blob.exists()) await blob.delete();
    final record = _recordFile(id);
    if (await record.exists()) await record.delete();
    rows[id] = StoredDocumentMetadata(
      id: current.id,
      fileName: current.fileName,
      mimeType: current.mimeType,
      byteLength: current.byteLength,
      createdAt: current.createdAt,
      deletedAt: _clock().toUtc(),
    );
    await _writeMetadata(rows.values);
  });

  Future<Map<String, StoredDocumentMetadata>> _readMetadata() async {
    if (!await _metadataFile.exists()) return {};
    return _withKey((key) async {
      Uint8List? clear;
      try {
        clear = await _engine.readFile(
          _metadataFile,
          keyBytes: key,
          associatedData: _metadataAad,
        );
        final decoded = jsonDecode(utf8.decode(clear));
        if (decoded is! Map || decoded['documents'] is! List) {
          throw const FormatException('Invalid document vault metadata.');
        }
        final result = <String, StoredDocumentMetadata>{};
        for (final row in (decoded['documents'] as List).whereType<Map>()) {
          final metadata = _tryMetadata(row);
          if (metadata != null) result[metadata.id] = metadata;
        }
        return result;
      } finally {
        _wipe(clear);
      }
    });
  }

  Future<void> _writeMetadata(Iterable<StoredDocumentMetadata> metadata) async {
    final ordered = metadata.toList()..sort((a, b) => a.id.compareTo(b.id));
    final clear = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'documents': ordered.map((row) => row.toJson()).toList(),
        }),
      ),
    );
    try {
      await _withKey((key) {
        return _engine.writeFile(
          _metadataFile,
          clear,
          keyBytes: key,
          associatedData: _metadataAad,
        );
      });
    } finally {
      _wipe(clear);
    }
  }

  Future<T> _withKey<T>(Future<T> Function(List<int> key) operation) async {
    var stored = await _keyStore.readKeyBytes();
    Uint8List? generated;
    if (stored == null || stored.length != EncryptedStorageEngine.keyLength) {
      final random = Random.secure();
      generated = Uint8List.fromList(
        List<int>.generate(
          EncryptedStorageEngine.keyLength,
          (_) => random.nextInt(256),
        ),
      );
      await _keyStore.writeKeyBytes(generated);
      stored = generated;
    }
    final key = List<int>.from(stored);
    try {
      return await operation(key);
    } finally {
      key.fillRange(0, key.length, 0);
      _wipe(generated);
    }
  }

  File _blobFile(String id) => File('${_directory.path}/blobs/$id.vault');
  File _recordFile(String id) => File('${_directory.path}/records/$id.vault');

  void _validateId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid document identifier.');
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

const _metadataAad = <int>[
  118,
  111,
  105,
  99,
  101,
  109,
  101,
  109,
  111,
  114,
  121,
  58,
  100,
  111,
  99,
  117,
  109,
  101,
  110,
  116,
  45,
  118,
  97,
  117,
  108,
  116,
  58,
  118,
  49,
  58,
  109,
  101,
  116,
  97,
  100,
  97,
  116,
  97,
];

List<int> _blobAad(String id) =>
    utf8.encode('voicememory:document-vault:v1:blob:$id');
List<int> _recordAad(String id) =>
    utf8.encode('voicememory:document-vault:v1:record:$id');

StoredDocumentMetadata? _tryMetadata(Map row) {
  try {
    return StoredDocumentMetadata.fromJson(Map<String, dynamic>.from(row));
  } on Object {
    return null;
  }
}

void _wipe(Uint8List? bytes) => bytes?.fillRange(0, bytes.length, 0);

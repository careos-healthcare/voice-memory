import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../../storage/private_data_encryption_key_store.dart';
import 'encrypted_storage_engine.dart';

enum SharedPayloadKind { text, url, image, file }

class SharedVaultPayload {
  SharedVaultPayload({
    required String id,
    required this.kind,
    required DateTime createdAt,
    String? text,
    String? mimeType,
    String? displayName,
    List<int>? bytes,
    Map<String, String> metadata = const {},
  }) : id = _required(id, 'id'),
       createdAt = createdAt.toUtc(),
       text = _boundedText(text),
       mimeType = _boundedOptional(mimeType, 128),
       displayName = _boundedOptional(displayName, 256),
       bytes = bytes == null ? null : Uint8List.fromList(bytes),
       metadata = Map.unmodifiable(_metadata(metadata)) {
    if (text == null && bytes == null) {
      throw ArgumentError('A shared payload requires text or bytes.');
    }
    if ((bytes?.length ?? 0) > SharedVaultStorage.maxPayloadBytes) {
      throw ArgumentError('Shared payload exceeds the size limit.');
    }
  }

  final String id;
  final SharedPayloadKind kind;
  final DateTime createdAt;
  final String? text;
  final String? mimeType;
  final String? displayName;
  final Uint8List? bytes;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'text': text,
    'mimeType': mimeType,
    'displayName': displayName,
    'bytesBase64': bytes == null ? null : base64Encode(bytes!),
    'metadata': metadata,
  };

  factory SharedVaultPayload.fromJson(Map<String, dynamic> json) {
    final kind = SharedPayloadKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final rawMetadata = json['metadata'];
    if (json['id'] is! String ||
        kind == null ||
        createdAt == null ||
        rawMetadata is! Map) {
      throw const FormatException('Invalid shared vault payload.');
    }
    Uint8List? bytes;
    final encoded = json['bytesBase64'];
    if (encoded != null) {
      if (encoded is! String ||
          encoded.length > SharedVaultStorage.maxBase64PayloadChars) {
        throw const FormatException('Invalid shared payload bytes.');
      }
      bytes = Uint8List.fromList(base64Decode(encoded));
    }
    return SharedVaultPayload(
      id: json['id'] as String,
      kind: kind,
      createdAt: createdAt,
      text: json['text'] as String?,
      mimeType: json['mimeType'] as String?,
      displayName: json['displayName'] as String?,
      bytes: bytes,
      metadata: {
        for (final entry in rawMetadata.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      },
    );
  }
}

abstract interface class SharedVaultPlatformBridge {
  Future<String?> sharedContainerPath();
  Future<List<SharedVaultPayload>> drainNativeInbox();
  Future<void> acknowledgeNativeInbox(Iterable<SharedVaultPayload> imported);
  Future<List<Map<String, Object?>>> drainWidgetActions();
  Future<Map<String, Object?>> extensionStatus();
  Future<void> publishWidgetSnapshot(Map<String, Object?> snapshot);
  Future<void> reloadWidgets();
}

enum SharedVaultPlatformEventType { shareReady, shareFailed }

class SharedVaultPlatformEvent {
  const SharedVaultPlatformEvent({
    required this.type,
    this.handoffId,
    this.errorCode,
  });

  final SharedVaultPlatformEventType type;
  final String? handoffId;
  final String? errorCode;
}

abstract interface class SharedVaultPlatformEventSource {
  Stream<SharedVaultPlatformEvent> get events;
}

class MethodChannelSharedVaultPlatformBridge
    implements SharedVaultPlatformBridge, SharedVaultPlatformEventSource {
  MethodChannelSharedVaultPlatformBridge({
    MethodChannel? channel,
    MethodChannel? androidChannel,
    bool? isAndroid,
  }) : _channel =
           channel ?? const MethodChannel('archive_me/os_level_integration'),
       _androidChannel =
           androidChannel ??
           const MethodChannel('archive_me/android_os_integration'),
       _isAndroid = isAndroid ?? Platform.isAndroid {
    _androidChannel.setMethodCallHandler(_handleAndroidEvent);
  }

  final MethodChannel _channel;
  final MethodChannel _androidChannel;
  final bool _isAndroid;
  final StreamController<SharedVaultPlatformEvent> _events =
      StreamController<SharedVaultPlatformEvent>.broadcast();

  @override
  Stream<SharedVaultPlatformEvent> get events => _events.stream;

  Future<void> _handleAndroidEvent(MethodCall call) async {
    final arguments = call.arguments;
    final values = arguments is Map
        ? Map<String, Object?>.from(arguments)
        : const <String, Object?>{};
    switch (call.method) {
      case 'shareHandoffReady':
        _events.add(
          SharedVaultPlatformEvent(
            type: SharedVaultPlatformEventType.shareReady,
            handoffId: values['id'] as String?,
          ),
        );
      case 'shareHandoffFailed':
        _events.add(
          SharedVaultPlatformEvent(
            type: SharedVaultPlatformEventType.shareFailed,
            errorCode: values['code'] as String?,
          ),
        );
    }
  }

  @override
  Future<String?> sharedContainerPath() async {
    try {
      return await _channel.invokeMethod<String>('sharedContainerPath');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<SharedVaultPayload>> drainNativeInbox() async {
    if (_isAndroid) return _drainAndroidInbox();
    try {
      final values = await _channel.invokeListMethod<dynamic>(
        'drainShareInbox',
      );
      return (values ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                SharedVaultPayload.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<void> acknowledgeNativeInbox(
    Iterable<SharedVaultPayload> imported,
  ) async {
    if (_isAndroid) {
      final handoffIds = imported
          .map((payload) => payload.metadata['nativeHandoffId'])
          .whereType<String>()
          .toSet();
      for (final id in handoffIds) {
        try {
          await _androidChannel.invokeMethod<bool>('deleteShareHandoff', {
            'id': id,
          });
        } on MissingPluginException {
          return;
        } on PlatformException {
          return;
        }
      }
      return;
    }
    try {
      await _channel.invokeMethod<void>('acknowledgeShareInbox', {
        'ids': imported.map((payload) => payload.id).toList(growable: false),
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  @override
  Future<List<Map<String, Object?>>> drainWidgetActions() async {
    if (_isAndroid) {
      try {
        final value = await _androidChannel.invokeMapMethod<String, Object?>(
          'consumePendingWidgetAction',
        );
        return value == null ? const [] : [value];
      } on MissingPluginException {
        return const [];
      } on PlatformException {
        return const [];
      }
    }
    try {
      final values = await _channel.invokeListMethod<dynamic>(
        'drainWidgetActions',
      );
      return (values ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<Map<String, Object?>> extensionStatus() async {
    if (_isAndroid) {
      try {
        final status = await _androidChannel.invokeMapMethod<String, Object?>(
          'extensionStatus',
        );
        if (status != null) return status;
        final available =
            await _androidChannel.invokeMethod<bool>('isAvailable') ?? false;
        return {
          'shareExtensionAvailable': available,
          'widgetExtensionAvailable': available,
          'sharedContainerAvailable': available,
        };
      } on MissingPluginException {
        return const {};
      } on PlatformException {
        return const {};
      }
    }
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'extensionStatus',
      );
      return value ?? const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  @override
  Future<void> publishWidgetSnapshot(Map<String, Object?> snapshot) async {
    if (_isAndroid) {
      try {
        await _androidChannel.invokeMethod<void>('updateWidgets', snapshot);
      } on MissingPluginException {
        return;
      } on PlatformException {
        return;
      }
      return;
    }
    try {
      await _channel.invokeMethod<void>('publishWidgetSnapshot', snapshot);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> reloadWidgets() async {
    if (_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('reloadWidgets');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<List<SharedVaultPayload>> _drainAndroidInbox() async {
    try {
      final handoffs = await _androidChannel.invokeListMethod<dynamic>(
        'listShareHandoffs',
      );
      final result = <SharedVaultPayload>[];
      for (final rawHandoff in (handoffs ?? const []).whereType<Map>()) {
        final handoff = Map<String, dynamic>.from(rawHandoff);
        final id = handoff['id'];
        final createdAtMillis = (handoff['createdAt'] as num?)?.toInt();
        final items = handoff['items'];
        if (id is! String ||
            createdAtMillis == null ||
            items is! List ||
            items.length > 12) {
          if (id is String) await _deleteAndroidHandoff(id);
          continue;
        }
        final parsed = <SharedVaultPayload>[];
        var complete = items.isNotEmpty;
        for (final rawItem in items) {
          if (rawItem is! Map) {
            complete = false;
            break;
          }
          final item = Map<String, dynamic>.from(rawItem);
          final index = (item['index'] as num?)?.toInt();
          final size = (item['size'] as num?)?.toInt();
          final kind = item['kind'];
          if (index == null ||
              size == null ||
              size <= 0 ||
              size > SharedVaultStorage.maxPayloadBytes ||
              kind is! String) {
            complete = false;
            break;
          }
          final value = await _androidChannel.invokeMethod<Uint8List>(
            'readShareItem',
            {'id': id, 'index': index, 'offset': 0, 'maxBytes': size},
          );
          if (value == null || value.length != size) {
            value?.fillRange(0, value.length, 0);
            complete = false;
            break;
          }
          if (kind == 'text' || kind == 'url') {
            late String text;
            try {
              text = utf8.decode(value, allowMalformed: false);
            } on FormatException {
              value.fillRange(0, value.length, 0);
              complete = false;
              break;
            }
            value.fillRange(0, value.length, 0);
            final uri = Uri.tryParse(text);
            parsed.add(
              SharedVaultPayload(
                id: '$id-$index',
                kind:
                    kind == 'url' ||
                        (uri != null &&
                            (uri.scheme == 'https' || uri.scheme == 'http'))
                    ? SharedPayloadKind.url
                    : SharedPayloadKind.text,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  createdAtMillis,
                  isUtc: true,
                ),
                text: text,
                mimeType: item['mimeType'] as String?,
                metadata: {'nativeHandoffId': id},
              ),
            );
          } else {
            parsed.add(
              SharedVaultPayload(
                id: '$id-$index',
                kind: kind == 'image'
                    ? SharedPayloadKind.image
                    : SharedPayloadKind.file,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  createdAtMillis,
                  isUtc: true,
                ),
                mimeType: item['mimeType'] as String?,
                displayName: item['name'] as String?,
                bytes: value,
                metadata: {'nativeHandoffId': id},
              ),
            );
          }
        }
        if (!complete) {
          for (final payload in parsed) {
            payload.bytes?.fillRange(0, payload.bytes!.length, 0);
          }
          await _deleteAndroidHandoff(id);
          continue;
        }
        result.addAll(parsed);
      }
      return result;
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _deleteAndroidHandoff(String id) async {
    try {
      await _androidChannel.invokeMethod<bool>('deleteShareHandoff', {
        'id': id,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

class SharedVaultStorage {
  SharedVaultStorage._({
    required this._database,
    required this.databasePath,
    required this._lockFile,
    required this._keyStore,
    EncryptedStorageEngine? engine,
  }) : _engine =
           engine ?? EncryptedStorageEngine(algorithm: AesGcm.with256bits());

  static const maxPayloadBytes = 20 * 1024 * 1024;
  static const maxBase64PayloadChars = 28 * 1024 * 1024;
  static const maxPendingPayloads = 128;

  final Database _database;
  final String databasePath;
  final File _lockFile;
  final PrivateDataEncryptionKeyStore _keyStore;
  final EncryptedStorageEngine _engine;
  Future<void> _tail = Future.value();
  bool _closed = false;

  static Future<SharedVaultStorage> open({
    required String fallbackDirectory,
    required PrivateDataEncryptionKeyStore keyStore,
    SharedVaultPlatformBridge? platform,
  }) async {
    final sharedPath = await platform?.sharedContainerPath();
    final directory = Directory(
      sharedPath?.trim().isNotEmpty == true ? sharedPath! : fallbackDirectory,
    );
    await directory.create(recursive: true);
    final databasePath = path.join(directory.path, 'shared_vault_outbox.db');
    final lockFile = File(path.join(directory.path, 'shared_vault.lock'));
    final lockHandle = await lockFile.open(mode: FileMode.append);
    late Database database;
    try {
      await lockHandle.lock(FileLock.exclusive);
      database = sqlite3.open(databasePath)
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA synchronous = FULL')
        ..execute('PRAGMA busy_timeout = 5000')
        ..execute('''
        CREATE TABLE IF NOT EXISTS shared_vault_outbox (
          payload_id TEXT PRIMARY KEY,
          encrypted_payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0
        )
      ''')
        ..execute('''
        CREATE TABLE IF NOT EXISTS shared_vault_media (
          payload_id TEXT PRIMARY KEY,
          encrypted_payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''')
        ..userVersion = 2;
    } finally {
      await lockHandle.unlock();
      await lockHandle.close();
    }
    return SharedVaultStorage._(
      database: database,
      databasePath: databasePath,
      lockFile: lockFile,
      keyStore: keyStore,
    );
  }

  Future<void> enqueue(SharedVaultPayload payload) => _serialized(() async {
    await _withInterprocessLock(() async {
      if (pendingCount >= maxPendingPayloads) {
        throw StateError('Shared vault outbox is full.');
      }
      final encrypted = await _encrypt(payload);
      _database.execute(
        '''
        INSERT OR IGNORE INTO shared_vault_outbox
          (payload_id, encrypted_payload, created_at)
        VALUES (?, ?, ?)
        ''',
        [payload.id, encrypted, payload.createdAt.toIso8601String()],
      );
    });
  });

  Future<int> importNativeInbox(SharedVaultPlatformBridge bridge) async {
    final incoming = await bridge.drainNativeInbox();
    final importedPayloads = <SharedVaultPayload>[];
    final remaining = (maxPendingPayloads - pendingCount).clamp(
      0,
      maxPendingPayloads,
    );
    for (final payload in incoming.take(remaining)) {
      try {
        await enqueue(payload);
      } on StateError {
        break;
      }
      importedPayloads.add(payload);
    }
    if (importedPayloads.isNotEmpty) {
      await bridge.acknowledgeNativeInbox(importedPayloads);
    }
    return importedPayloads.length;
  }

  int get pendingCount {
    _ensureOpen();
    return _database
            .select('SELECT COUNT(*) AS count FROM shared_vault_outbox')
            .single['count']
        as int;
  }

  Future<List<SharedVaultPayload>> pending({int limit = 32}) =>
      _serialized(() async {
        final boundedLimit = limit.clamp(1, maxPendingPayloads);
        return _withInterprocessLock(() async {
          final rows = _database.select(
            'SELECT encrypted_payload FROM shared_vault_outbox '
            'ORDER BY created_at, payload_id LIMIT ?',
            [boundedLimit],
          );
          final result = <SharedVaultPayload>[];
          for (final row in rows) {
            result.add(await _decrypt(row['encrypted_payload'] as String));
          }
          return List.unmodifiable(result);
        });
      });

  Future<void> markProcessed(String payloadId) => _serialized(() async {
    await _withInterprocessLock(() async {
      _database.execute(
        'DELETE FROM shared_vault_outbox WHERE payload_id = ?',
        [payloadId],
      );
    });
  });

  /// Retains an encrypted file payload in the local shared-media vault before
  /// its outbox row is acknowledged. The ciphertext is copied directly inside
  /// SQLite; plaintext bytes are never written to a temporary file.
  Future<void> retainFile(String payloadId) => _serialized(() async {
    await _withInterprocessLock(() async {
      _database.execute(
        '''
        INSERT OR REPLACE INTO shared_vault_media
          (payload_id, encrypted_payload, created_at)
        SELECT payload_id, encrypted_payload, created_at
        FROM shared_vault_outbox
        WHERE payload_id = ?
        ''',
        [payloadId],
      );
    });
  });

  Future<SharedVaultPayload?> retainedFile(String payloadId) =>
      _serialized(() async {
        return _withInterprocessLock(() async {
          final rows = _database.select(
            'SELECT encrypted_payload FROM shared_vault_media '
            'WHERE payload_id = ? LIMIT 1',
            [payloadId],
          );
          if (rows.isEmpty) return null;
          return _decrypt(rows.single['encrypted_payload'] as String);
        });
      });

  Future<void> markAttempted(String payloadId) => _serialized(() async {
    await _withInterprocessLock(() async {
      _database.execute(
        'UPDATE shared_vault_outbox SET attempts = attempts + 1 '
        'WHERE payload_id = ?',
        [payloadId],
      );
    });
  });

  void checkpoint() {
    _ensureOpen();
    _database.execute('PRAGMA wal_checkpoint(FULL)');
  }

  Future<String> _encrypt(SharedVaultPayload payload) async {
    final key = await _requiredKey();
    final clear = utf8.encode(jsonEncode(payload.toJson()));
    try {
      return jsonEncode(await _engine.encrypt(clear, keyBytes: key));
    } finally {
      clear.fillRange(0, clear.length, 0);
      key.fillRange(0, key.length, 0);
    }
  }

  Future<SharedVaultPayload> _decrypt(String encoded) async {
    final key = await _requiredKey();
    List<int>? clear;
    try {
      final envelope = jsonDecode(encoded);
      if (envelope is! Map) {
        throw const FormatException('Invalid shared vault envelope.');
      }
      clear = await _engine.decrypt(
        Map<String, dynamic>.from(envelope),
        keyBytes: key,
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map) {
        throw const FormatException('Invalid shared vault payload.');
      }
      return SharedVaultPayload.fromJson(Map<String, dynamic>.from(decoded));
    } finally {
      clear?.fillRange(0, clear.length, 0);
      key.fillRange(0, key.length, 0);
    }
  }

  Future<List<int>> _requiredKey() async {
    if (_keyStore is SecurePrivateDataEncryptionKeyStore) {
      await (_keyStore).ensureKey();
    } else if (_keyStore is InMemoryPrivateDataEncryptionKeyStore) {
      await (_keyStore).ensureKey();
    }
    final key = await _keyStore.readKeyBytes();
    if (key == null ||
        key.length != SecurePrivateDataEncryptionKeyStore.keyByteLength) {
      throw StateError('Shared vault encryption key is unavailable.');
    }
    return key;
  }

  Future<T> _withInterprocessLock<T>(Future<T> Function() operation) async {
    await _lockFile.parent.create(recursive: true);
    final handle = await _lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      return await operation();
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    _ensureOpen();
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

  Future<void> close() async {
    if (_closed) return;
    await _tail.catchError((Object _) {});
    checkpoint();
    _closed = true;
    _database.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Shared vault storage is closed.');
  }
}

String _required(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(value, field);
  }
  return normalized;
}

String? _boundedText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > 100000) {
    throw ArgumentError.value(value, 'text', 'is too long');
  }
  return normalized;
}

String? _boundedOptional(String? value, int maxLength) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw ArgumentError.value(value, 'value', 'is too long');
  }
  return normalized;
}

Map<String, String> _metadata(Map<String, String> values) {
  if (values.length > 16) throw ArgumentError('Too much shared metadata.');
  return {
    for (final entry in values.entries)
      if (entry.key.trim().isNotEmpty)
        _boundedOptional(entry.key, 64)!:
            _boundedOptional(entry.value, 512) ?? '',
  };
}

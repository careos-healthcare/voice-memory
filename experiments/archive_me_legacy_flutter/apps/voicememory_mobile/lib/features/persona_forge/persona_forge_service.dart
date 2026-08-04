import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../storage/private_data_encryption_key_store.dart';
import '../cognitive_council/council_persona.dart';

final class PersonaPackageException implements Exception {
  const PersonaPackageException(this.message);
  final String message;

  @override
  String toString() => 'PersonaPackageException: $message';
}

/// Field-encrypted SQLite repository for custom Cognitive Council personas.
///
/// SQLite sees only opaque IDs, timestamps, nonces, authentication tags and
/// ciphertext. Prompts, cluster permissions and avatar bytes remain encrypted.
final class PersonaForgeService {
  PersonaForgeService._({
    required this._database,
    required this.databasePath,
    required this._keyStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const packageFormat = 'voicememory.persona';
  static const packageVersion = 1;
  static const packageKdfIterations = 210000;
  static const maxPackageBytes = 4 * 1024 * 1024;

  final Database _database;
  final String databasePath;
  final PrivateDataEncryptionKeyStore _keyStore;
  final DateTime Function() _clock;
  final AesGcm _aes = AesGcm.with256bits();
  final Random _random = Random.secure();
  bool _closed = false;

  static PersonaForgeService open({
    required String databasePath,
    required PrivateDataEncryptionKeyStore keyStore,
    DateTime Function()? clock,
  }) {
    Directory(databasePath).parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA secure_delete = ON')
      ..execute('PRAGMA busy_timeout = 3000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS council_personas (
          id TEXT PRIMARY KEY,
          ciphertext BLOB NOT NULL,
          nonce BLOB NOT NULL,
          mac BLOB NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    return PersonaForgeService._(
      database: database,
      databasePath: databasePath,
      keyStore: keyStore,
      clock: clock,
    );
  }

  Future<List<CouncilPersona>> list() async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, ciphertext, nonce, mac FROM council_personas '
      'ORDER BY updated_at DESC, id ASC',
    );
    final result = <CouncilPersona>[];
    for (final row in rows) {
      result.add(await _decodeRow(row));
    }
    return List.unmodifiable(result);
  }

  Future<CouncilPersona?> get(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, ciphertext, nonce, mac FROM council_personas WHERE id = ?',
      [id.trim()],
    );
    return rows.isEmpty ? null : _decodeRow(rows.single);
  }

  Future<CouncilPersona> create({
    required String name,
    required String archetypeTitle,
    required String systemPrompt,
    Map<String, String> localizedSystemPrompts = const {},
    required num temperature,
    required Iterable<String> restrictedClusterIds,
    String avatarAsset = 'psychology',
    Uint8List? avatarImage,
  }) async {
    final now = _clock().toUtc();
    final persona = CouncilPersona(
      id: const Uuid().v4(),
      name: name,
      avatarAsset: avatarAsset,
      avatarImage: avatarImage,
      archetypeTitle: archetypeTitle,
      systemPrompt: systemPrompt,
      localizedSystemPrompts: localizedSystemPrompts,
      temperature: temperature,
      restrictedClusterIds: restrictedClusterIds,
      createdAt: now,
      updatedAt: now,
    );
    await _write(persona, insertOnly: true);
    return persona;
  }

  Future<CouncilPersona> update(CouncilPersona persona) async {
    if (await get(persona.id) == null) {
      throw StateError('Persona does not exist: ${persona.id}');
    }
    final updated = persona.copyWith(updatedAt: _clock().toUtc());
    await _write(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    _ensureOpen();
    _database.execute('DELETE FROM council_personas WHERE id = ?', [id.trim()]);
  }

  Future<void> clear() async {
    _ensureOpen();
    _database.execute('DELETE FROM council_personas');
  }

  Future<File> exportPersona({
    required CouncilPersona persona,
    required File output,
    required String passphrase,
  }) async {
    if (!output.path.toLowerCase().endsWith('.persona')) {
      throw const PersonaPackageException(
        'Persona packages must use the .persona extension.',
      );
    }
    final bytes = await exportPortableBytes(
      persona: persona,
      passphrase: passphrase,
    );
    await output.parent.create(recursive: true);
    final temporary = File('${output.path}.$pid.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(output.path);
    return output;
  }

  Future<Uint8List> exportPortableBytes({
    required CouncilPersona persona,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _packageKey(passphrase, salt);
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode({'persona': persona.toJson()})),
    );
    try {
      final box = await _aes.encrypt(
        plaintext,
        secretKey: key,
        nonce: nonce,
        aad: _packageAad(),
      );
      final envelope = utf8.encode(
        jsonEncode({
          'format': packageFormat,
          'version': packageVersion,
          'kdf': 'PBKDF2-HMAC-SHA256',
          'iterations': packageKdfIterations,
          'cipher': 'AES-256-GCM',
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
          'ciphertext': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      );
      if (envelope.length > maxPackageBytes) {
        throw const PersonaPackageException('Persona package is too large.');
      }
      return Uint8List.fromList(envelope);
    } finally {
      _wipe(plaintext);
    }
  }

  Future<String> exportQrPayload({
    required CouncilPersona persona,
    required String passphrase,
  }) async {
    final bytes = await exportPortableBytes(
      persona: persona,
      passphrase: passphrase,
    );
    return 'vm-persona://v1/${base64UrlEncode(bytes)}';
  }

  Future<CouncilPersona> importPersona({
    required File input,
    required String passphrase,
  }) async {
    if (!input.path.toLowerCase().endsWith('.persona')) {
      throw const PersonaPackageException(
        'Persona packages must use the .persona extension.',
      );
    }
    if (!input.existsSync() || input.lengthSync() > maxPackageBytes) {
      throw const PersonaPackageException('Persona package is unavailable.');
    }
    return importPortableBytes(
      bytes: Uint8List.fromList(await input.readAsBytes()),
      passphrase: passphrase,
    );
  }

  Future<CouncilPersona> importQrPayload({
    required String payload,
    required String passphrase,
  }) {
    const prefix = 'vm-persona://v1/';
    if (!payload.startsWith(prefix)) {
      throw const PersonaPackageException('Invalid persona QR payload.');
    }
    return importPortableBytes(
      bytes: base64Url.decode(payload.substring(prefix.length)),
      passphrase: passphrase,
    );
  }

  Future<CouncilPersona> importPortableBytes({
    required Uint8List bytes,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    if (bytes.isEmpty || bytes.length > maxPackageBytes) {
      throw const PersonaPackageException('Invalid persona package size.');
    }
    try {
      final envelope = jsonDecode(utf8.decode(bytes));
      if (envelope is! Map ||
          envelope['format'] != packageFormat ||
          envelope['version'] != packageVersion ||
          envelope['iterations'] != packageKdfIterations) {
        throw const PersonaPackageException('Unsupported persona package.');
      }
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      final clear = await _aes.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: await _packageKey(passphrase, salt),
        aad: _packageAad(),
      );
      try {
        final payload = jsonDecode(utf8.decode(clear));
        final rawPersona = payload is Map ? payload['persona'] : null;
        if (rawPersona is! Map) {
          throw const PersonaPackageException('Persona payload is missing.');
        }
        final persona = CouncilPersona.fromJson(
          Map<String, dynamic>.from(rawPersona),
        );
        await _write(persona);
        return persona;
      } finally {
        _wipe(clear);
      }
    } on PersonaPackageException {
      rethrow;
    } on Object {
      throw const PersonaPackageException(
        'The package password is wrong or its contents were altered.',
      );
    }
  }

  Future<void> _write(CouncilPersona persona, {bool insertOnly = false}) async {
    _ensureOpen();
    final nonce = _randomBytes(12);
    final clear = Uint8List.fromList(utf8.encode(jsonEncode(persona.toJson())));
    try {
      final box = await _aes.encrypt(
        clear,
        secretKey: SecretKey(await _ensureKeyBytes()),
        nonce: nonce,
        aad: utf8.encode('$packageFormat|local|${persona.id}'),
      );
      _database.execute(
        '${insertOnly ? 'INSERT' : 'INSERT OR REPLACE'} INTO council_personas'
        '(id, ciphertext, nonce, mac, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          persona.id,
          Uint8List.fromList(box.cipherText),
          nonce,
          Uint8List.fromList(box.mac.bytes),
          persona.updatedAt.millisecondsSinceEpoch,
        ],
      );
    } finally {
      _wipe(clear);
    }
  }

  Future<CouncilPersona> _decodeRow(Row row) async {
    final id = row['id'] as String;
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          Uint8List.fromList(row['ciphertext'] as Uint8List),
          nonce: Uint8List.fromList(row['nonce'] as Uint8List),
          mac: Mac(Uint8List.fromList(row['mac'] as Uint8List)),
        ),
        secretKey: SecretKey(await _ensureKeyBytes()),
        aad: utf8.encode('$packageFormat|local|$id'),
      );
      try {
        final persona = CouncilPersona.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
        );
        if (persona.id != id) {
          throw StateError('Persona identity authentication failed.');
        }
        return persona;
      } finally {
        _wipe(clear);
      }
    } on Object catch (error) {
      throw StateError('Could not decrypt persona $id: $error');
    }
  }

  Future<List<int>> _ensureKeyBytes() async {
    final existing = await _keyStore.readKeyBytes();
    if (existing != null && existing.length == 32) return existing;
    final bytes = await (await _aes.newSecretKey()).extractBytes();
    await _keyStore.writeKeyBytes(bytes);
    return bytes;
  }

  Future<SecretKey> _packageKey(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: packageKdfIterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );

  static Uint8List _packageAad() => Uint8List.fromList(
    utf8.encode('$packageFormat|$packageVersion|AES-256-GCM'),
  );

  static void _validatePassphrase(String value) {
    if (value.length < 12 || value.length > 1024) {
      throw const PersonaPackageException(
        'Package passwords must contain 12-1024 characters.',
      );
    }
  }

  static void _wipe(List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('PersonaForgeService is closed.');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }
}

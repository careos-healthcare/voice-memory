import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// On-disk layout for a chunked AES-GCM backup.
///
/// The header is a fixed 58 bytes. A wrong passphrase fails that header tag
/// and never opens the chunk payload.
abstract final class StreamingCryptoFormat {
  static const List<int> magic = <int>[0x56, 0x4D, 0x53, 0x54];
  static const int version = 1;
  static const int kdfPbkdf2Sha256 = 1;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int headerPlainLength = 16;

  /// PBKDF2-HMAC-SHA256 rounds stored in the header.
  ///
  /// The header check has to reject a wrong passphrase in under 50ms, which
  /// caps this count. Each backup still uses a fresh salt, and every chunk
  /// carries its own GCM tag.
  static const int kdfIterations = 10000;

  static const int chunk64KiB = 64 * 1024;
  static const int chunk1MiB = 1024 * 1024;
  static const int maxChunkSize = chunk1MiB;

  static const int iterationsOffset = 6;
  static const int saltOffset = 10;
  static const int cipherOffset = 26;
  static const int headerLength = cipherOffset + headerPlainLength + tagLength;
}

/// Failure while sealing or opening a streamed backup.
final class StreamingCryptoException implements Exception {
  const StreamingCryptoException(this.code);

  final String code;

  @override
  String toString() => 'StreamingCryptoException($code)';
}

/// Bytes sealed and how long the isolate spent doing it.
final class StreamingCryptoReport {
  const StreamingCryptoReport({
    required this.sourceBytes,
    required this.elapsedMilliseconds,
    required this.chunkSize,
    required this.chunkCount,
  });

  final int sourceBytes;
  final int elapsedMilliseconds;
  final int chunkSize;
  final int chunkCount;
}

/// Job copied into the background isolate. Paths only, never the file bytes.
final class StreamingCryptoJob {
  const StreamingCryptoJob({
    required this.sourcePath,
    required this.destinationPath,
    required this.passphrase,
    required this.chunkSize,
    required this.iterations,
  });

  final String sourcePath;
  final String destinationPath;
  final String passphrase;
  final int chunkSize;
  final int iterations;
}

/// Chunked AES-GCM 256 for SQLite backups that do not fit in memory.
///
/// [encryptStream] and the payload half of [decryptStream] run in a background
/// isolate. The passphrase check reads [StreamingCryptoFormat.headerLength]
/// bytes, derives the key, and stops when the header tag does not match.
final class StreamingCryptoService {
  StreamingCryptoService({
    this.chunkSize = StreamingCryptoFormat.chunk64KiB,
    this.iterations = StreamingCryptoFormat.kdfIterations,
  }) {
    _requireChunkSize(chunkSize);
    if (iterations <= 0) {
      throw ArgumentError.value(iterations, 'iterations', 'must be positive');
    }
  }

  final int chunkSize;
  final int iterations;

  /// Seals [sourceDb] into [destinationEncrypted] in 64KB or 1MB chunks.
  Future<StreamingCryptoReport> encryptStream(
    File sourceDb,
    String passphrase,
    File destinationEncrypted,
  ) {
    final job = _job(
      source: sourceDb,
      destination: destinationEncrypted,
      passphrase: passphrase,
      chunkSize: chunkSize,
      iterations: iterations,
    );
    return Isolate.run(() => _encryptStreamingFile(job));
  }

  /// Opens [encryptedFile] into [destinationDb].
  ///
  /// A wrong passphrase throws [StreamingCryptoException] with
  /// `WRONG_PASSPHRASE` after the header only. The chunk payload stays unread.
  Future<StreamingCryptoReport> decryptStream(
    File encryptedFile,
    String passphrase,
    File destinationDb,
  ) async {
    final trimmed = _requirePassphrase(passphrase);
    await _rejectWrongPassphrase(encryptedFile, trimmed);
    return Isolate.run(
      () => _decryptStreamingFile(
        StreamingCryptoJob(
          sourcePath: encryptedFile.path,
          destinationPath: destinationDb.path,
          passphrase: trimmed,
          chunkSize: chunkSize,
          iterations: iterations,
        ),
      ),
    );
  }
}

StreamingCryptoJob _job({
  required File source,
  required File destination,
  required String passphrase,
  required int chunkSize,
  required int iterations,
}) {
  return StreamingCryptoJob(
    sourcePath: source.path,
    destinationPath: destination.path,
    passphrase: _requirePassphrase(passphrase),
    chunkSize: chunkSize,
    iterations: iterations,
  );
}

String _requirePassphrase(String passphrase) {
  final trimmed = passphrase.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(passphrase, 'passphrase', 'required');
  }
  return trimmed;
}

void _requireChunkSize(int chunkSize) {
  if (chunkSize <= 0 || chunkSize > StreamingCryptoFormat.maxChunkSize) {
    throw ArgumentError.value(
      chunkSize,
      'chunkSize',
      'must be between 1 byte and 1MB',
    );
  }
}

Future<StreamingCryptoReport> _encryptStreamingFile(StreamingCryptoJob job) async {
  final watch = Stopwatch()..start();
  final source = File(job.sourcePath);
  final sourceLength = source.lengthSync();
  final chunkCount = sourceLength == 0
      ? 0
      : (sourceLength + job.chunkSize - 1) ~/ job.chunkSize;
  final salt = _salt();
  final secretKey = await _deriveKey(job.passphrase, salt, job.iterations);
  final algorithm = AesGcm.with256bits();
  final input = source.openSync();
  final output = File(job.destinationPath).openSync(mode: FileMode.write);
  try {
    final headerPlain = Uint8List(StreamingCryptoFormat.headerPlainLength);
    ByteData.sublistView(headerPlain)
      ..setUint64(0, sourceLength)
      ..setUint32(8, job.chunkSize)
      ..setUint32(12, chunkCount);
    final headerBox = await algorithm.encrypt(
      headerPlain,
      secretKey: secretKey,
      nonce: _nonce(0),
      aad: _headerAad(job.iterations, salt),
    );
    output.writeFromSync(
      _headerBytes(
        iterations: job.iterations,
        salt: salt,
        box: headerBox,
      ),
    );

    final buffer = Uint8List(job.chunkSize);
    var remaining = sourceLength;
    var index = 0;
    while (remaining > 0) {
      final want = remaining < job.chunkSize ? remaining : job.chunkSize;
      _readExactInto(input, buffer, want);
      final slice = want == buffer.length
          ? buffer
          : Uint8List.sublistView(buffer, 0, want);
      final box = await algorithm.encrypt(
        slice,
        secretKey: secretKey,
        nonce: _nonce(index + 1),
        aad: _chunkAad(index + 1),
      );
      _writeFrame(output, box);
      remaining -= want;
      index += 1;
    }
    output.flushSync();
  } finally {
    input.closeSync();
    output.closeSync();
  }
  watch.stop();
  return StreamingCryptoReport(
    sourceBytes: sourceLength,
    elapsedMilliseconds: watch.elapsedMilliseconds,
    chunkSize: job.chunkSize,
    chunkCount: chunkCount,
  );
}

Future<StreamingCryptoReport> _decryptStreamingFile(StreamingCryptoJob job) async {
  final watch = Stopwatch()..start();
  final input = File(job.sourcePath).openSync();
  final output = File(job.destinationPath).openSync(mode: FileMode.write);
  try {
    final opened = await _openHeader(input, job.passphrase);
    final buffer = Uint8List(opened.chunkSize);
    final lengthBytes = Uint8List(4);
    var remaining = opened.plaintextLength;
    for (var index = 0; index < opened.chunkCount; index++) {
      _readExactInto(input, lengthBytes, lengthBytes.length);
      final length = ByteData.sublistView(lengthBytes).getUint32(0);
      if (length <= 0 || length > opened.chunkSize || length > remaining) {
        throw const StreamingCryptoException('CORRUPT_PAYLOAD');
      }
      _readExactInto(input, buffer, length);
      final cipher = length == buffer.length
          ? buffer
          : Uint8List.sublistView(buffer, 0, length);
      final mac = Uint8List(StreamingCryptoFormat.tagLength);
      _readExactInto(input, mac, mac.length);
      final clear = await _decryptFrame(
        algorithm: opened.algorithm,
        secretKey: opened.secretKey,
        cipher: cipher,
        mac: mac,
        nonceIndex: index + 1,
      );
      output.writeFromSync(clear);
      remaining -= length;
    }
    if (remaining != 0) {
      throw const StreamingCryptoException('CORRUPT_PAYLOAD');
    }
    output.flushSync();
    watch.stop();
    return StreamingCryptoReport(
      sourceBytes: opened.plaintextLength,
      elapsedMilliseconds: watch.elapsedMilliseconds,
      chunkSize: opened.chunkSize,
      chunkCount: opened.chunkCount,
    );
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

Future<void> _rejectWrongPassphrase(File encryptedFile, String passphrase) async {
  final input = encryptedFile.openSync();
  try {
    final header = _readExact(input, StreamingCryptoFormat.headerLength);
    await _headerSecret(header, passphrase);
  } on SecretBoxAuthenticationError {
    throw const StreamingCryptoException('WRONG_PASSPHRASE');
  } finally {
    input.closeSync();
  }
}

Future<_OpenedHeader> _openHeader(
  RandomAccessFile input,
  String passphrase,
) async {
  final header = _readExact(input, StreamingCryptoFormat.headerLength);
  try {
    return await _headerSecret(header, passphrase);
  } on SecretBoxAuthenticationError {
    throw const StreamingCryptoException('WRONG_PASSPHRASE');
  }
}

Future<_OpenedHeader> _headerSecret(Uint8List header, String passphrase) async {
  if (header.length != StreamingCryptoFormat.headerLength ||
      !_matchesMagic(header)) {
    throw const StreamingCryptoException('UNSUPPORTED_FORMAT');
  }
  if (header[4] != StreamingCryptoFormat.version) {
    throw const StreamingCryptoException('UNSUPPORTED_VERSION');
  }
  if (header[5] != StreamingCryptoFormat.kdfPbkdf2Sha256) {
    throw const StreamingCryptoException('UNSUPPORTED_KDF');
  }
  final view = ByteData.sublistView(header);
  final iterations = view.getUint32(StreamingCryptoFormat.iterationsOffset);
  if (iterations <= 0) {
    throw const StreamingCryptoException('UNSUPPORTED_FORMAT');
  }
  final salt = Uint8List.fromList(
    header.sublist(
      StreamingCryptoFormat.saltOffset,
      StreamingCryptoFormat.saltOffset + StreamingCryptoFormat.saltLength,
    ),
  );
  final secretKey = await _deriveKey(passphrase, salt, iterations);
  final algorithm = AesGcm.with256bits();
  final cipher = Uint8List.sublistView(
    header,
    StreamingCryptoFormat.cipherOffset,
    StreamingCryptoFormat.cipherOffset +
        StreamingCryptoFormat.headerPlainLength,
  );
  final mac = Uint8List.sublistView(
    header,
    StreamingCryptoFormat.headerLength - StreamingCryptoFormat.tagLength,
  );
  final clear = await algorithm.decrypt(
    SecretBox(cipher, nonce: _nonce(0), mac: Mac(mac)),
    secretKey: secretKey,
    aad: _headerAad(iterations, salt),
  );
  if (clear.length != StreamingCryptoFormat.headerPlainLength) {
    throw const StreamingCryptoException('CORRUPT_PAYLOAD');
  }
  final plain = ByteData.sublistView(Uint8List.fromList(clear));
  final plaintextLength = plain.getUint64(0);
  final chunkSize = plain.getUint32(8);
  final chunkCount = plain.getUint32(12);
  if (chunkSize <= 0 || chunkSize > StreamingCryptoFormat.maxChunkSize) {
    throw const StreamingCryptoException('CORRUPT_PAYLOAD');
  }
  return _OpenedHeader(
    algorithm: algorithm,
    secretKey: secretKey,
    plaintextLength: plaintextLength,
    chunkSize: chunkSize,
    chunkCount: chunkCount,
  );
}

Uint8List _headerBytes({
  required int iterations,
  required Uint8List salt,
  required SecretBox box,
}) {
  final header = Uint8List(StreamingCryptoFormat.headerLength);
  ByteData.sublistView(header)
    ..setUint8(4, StreamingCryptoFormat.version)
    ..setUint8(5, StreamingCryptoFormat.kdfPbkdf2Sha256)
    ..setUint32(StreamingCryptoFormat.iterationsOffset, iterations);
  header
    ..setRange(
      0,
      StreamingCryptoFormat.magic.length,
      StreamingCryptoFormat.magic,
    )
    ..setRange(
      StreamingCryptoFormat.saltOffset,
      StreamingCryptoFormat.saltOffset + StreamingCryptoFormat.saltLength,
      salt,
    )
    ..setRange(
      StreamingCryptoFormat.cipherOffset,
      StreamingCryptoFormat.cipherOffset + box.cipherText.length,
      box.cipherText,
    )
    ..setRange(
      StreamingCryptoFormat.headerLength - StreamingCryptoFormat.tagLength,
      StreamingCryptoFormat.headerLength,
      box.mac.bytes,
    );
  return header;
}

void _writeFrame(RandomAccessFile output, SecretBox box) {
  final lengthBytes = Uint8List(4);
  ByteData.sublistView(lengthBytes).setUint32(0, box.cipherText.length);
  output
    ..writeFromSync(lengthBytes)
    ..writeFromSync(box.cipherText)
    ..writeFromSync(box.mac.bytes);
}

Future<List<int>> _decryptFrame({
  required AesGcm algorithm,
  required SecretKey secretKey,
  required Uint8List cipher,
  required Uint8List mac,
  required int nonceIndex,
}) async {
  try {
    return await algorithm.decrypt(
      SecretBox(cipher, nonce: _nonce(nonceIndex), mac: Mac(mac)),
      secretKey: secretKey,
      aad: _chunkAad(nonceIndex),
    );
  } on SecretBoxAuthenticationError {
    throw const StreamingCryptoException('CORRUPT_PAYLOAD');
  }
}

Future<SecretKey> _deriveKey(
  String passphrase,
  Uint8List salt,
  int iterations,
) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final secret = await pbkdf2.deriveKeyFromPassword(
    password: passphrase,
    nonce: salt,
  );
  return SecretKey(await secret.extractBytes());
}

Uint8List _salt() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(
      StreamingCryptoFormat.saltLength,
      (_) => random.nextInt(256),
    ),
  );
}

Uint8List _nonce(int index) {
  final nonce = Uint8List(StreamingCryptoFormat.nonceLength);
  ByteData.sublistView(nonce).setUint32(8, index);
  return nonce;
}

Uint8List _headerAad(int iterations, Uint8List salt) {
  final aad = Uint8List(4 + 4 + salt.length);
  ByteData.sublistView(aad).setUint32(4, iterations);
  aad
    ..setRange(0, StreamingCryptoFormat.magic.length, StreamingCryptoFormat.magic)
    ..setRange(8, aad.length, salt);
  return aad;
}

Uint8List _chunkAad(int nonceIndex) {
  final aad = Uint8List(8);
  ByteData.sublistView(aad).setUint32(4, nonceIndex);
  aad.setRange(0, StreamingCryptoFormat.magic.length, StreamingCryptoFormat.magic);
  return aad;
}

bool _matchesMagic(Uint8List header) {
  for (var i = 0; i < StreamingCryptoFormat.magic.length; i++) {
    if (header[i] != StreamingCryptoFormat.magic[i]) {
      return false;
    }
  }
  return true;
}

Uint8List _readExact(RandomAccessFile file, int count) {
  final bytes = file.readSync(count);
  if (bytes.length != count) {
    throw const StreamingCryptoException('TRUNCATED');
  }
  return bytes;
}

void _readExactInto(RandomAccessFile file, Uint8List buffer, int count) {
  var offset = 0;
  while (offset < count) {
    final read = file.readIntoSync(buffer, offset, count);
    if (read <= 0) {
      throw const StreamingCryptoException('TRUNCATED');
    }
    offset += read;
  }
}

final class _OpenedHeader {
  const _OpenedHeader({
    required this.algorithm,
    required this.secretKey,
    required this.plaintextLength,
    required this.chunkSize,
    required this.chunkCount,
  });

  final AesGcm algorithm;
  final SecretKey secretKey;
  final int plaintextLength;
  final int chunkSize;
  final int chunkCount;
}

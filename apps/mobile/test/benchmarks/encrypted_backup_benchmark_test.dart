import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/sync/streaming_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const List<int> _sizesMb = <int>[10, 50, 100, 200];
const _passphrase = 'archive-backup-passphrase';
const int _rssLimitBytes = 30 * 1024 * 1024;

void main() {
  test(
    'chunked AES-GCM backups stay under 30MB and reject a bad passphrase fast',
    () async {
      final directory = Directory.systemTemp.createTempSync('stream-backup-bench');
      addTearDown(() => directory.deleteSync(recursive: true));
      final results = <Map<String, Object?>>[];
      Object? failure;
      StackTrace? stack;
      try {
        await _roundTrip(
          directory: directory,
          label: '64KB chunks',
          targetBytes: 256 * 1024,
          chunkSize: StreamingCryptoFormat.chunk64KiB,
        );
        for (final sizeMb in _sizesMb) {
          results.add(
            await _measureSize(
              directory: directory,
              sizeMb: sizeMb,
            ),
          );
        }
        final largest = results.last;
        expect(largest['rssDeltaBytes']! as int, lessThan(_rssLimitBytes));
        expect(largest['uiTicks']! as int, greaterThan(0));
        expect(largest['wrongPassphraseMilliseconds']! as int, lessThan(50));
        expect(
          largest['headerOnlyRejectMilliseconds']! as int,
          lessThan(50),
        );
        expect(largest['verified'], isTrue);
      } on Object catch (error, trace) {
        failure = error;
        stack = trace;
      } finally {
        _writeResults(<String, Object?>{
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'algorithm': 'AES-GCM-256',
          'kdf': 'PBKDF2-HMAC-SHA256',
          'kdfIterations': StreamingCryptoFormat.kdfIterations,
          'headerBytes': StreamingCryptoFormat.headerLength,
          'results': results,
          'table': _markdownTable(results),
        });
        stdout.writeln(_markdownTable(results));
      }
      if (failure != null) {
        Error.throwWithStackTrace(failure, stack!);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _roundTrip({
  required Directory directory,
  required String label,
  required int targetBytes,
  required int chunkSize,
}) async {
  final source = File('${directory.path}/$label.db');
  final encrypted = File('${directory.path}/$label.enc');
  final restored = File('${directory.path}/$label.restored.db');
  _writeSqlite(source.path, targetBytes);
  final service = StreamingCryptoService(chunkSize: chunkSize);
  await service.encryptStream(source, _passphrase, encrypted);
  await service.decryptStream(encrypted, _passphrase, restored);
  expect(_filesEqual(source, restored), isTrue);
  expect(encrypted.lengthSync(), greaterThan(StreamingCryptoFormat.headerLength));
}

Future<Map<String, Object?>> _measureSize({
  required Directory directory,
  required int sizeMb,
}) async {
  final source = File('${directory.path}/backup-$sizeMb.db');
  final encrypted = File('${directory.path}/backup-$sizeMb.enc');
  final restored = File('${directory.path}/backup-$sizeMb.restored.db');
  _writeSqlite(source.path, sizeMb * 1024 * 1024);
  final service = StreamingCryptoService(
    chunkSize: StreamingCryptoFormat.chunk1MiB,
  );

  final baselineRss = ProcessInfo.currentRss;
  var peakRss = baselineRss;
  var ticks = 0;
  final subscription = Stream<void>.periodic(
    const Duration(milliseconds: 5),
  ).listen((_) {
    ticks += 1;
    final rss = ProcessInfo.currentRss;
    if (rss > peakRss) {
      peakRss = rss;
    }
  });
  final encryptWatch = Stopwatch()..start();
  final encryptedReport = await service.encryptStream(
    source,
    _passphrase,
    encrypted,
  );
  encryptWatch.stop();
  final rssAfterEncrypt = ProcessInfo.currentRss;
  if (rssAfterEncrypt > peakRss) {
    peakRss = rssAfterEncrypt;
  }
  unawaited(subscription.cancel());

  final decryptWatch = Stopwatch()..start();
  await service.decryptStream(encrypted, _passphrase, restored);
  decryptWatch.stop();

  final verified = _filesEqual(source, restored) && _sqliteRowCount(restored.path) > 0;
  final headerOnlyMilliseconds = await _rejectHeaderOnly(directory, encrypted);
  final wrongPassphraseMilliseconds = await _rejectFullFile(encrypted, restored);

  final sourceBytes = source.lengthSync();
  return <String, Object?>{
    'sizeMb': sizeMb,
    'sourceBytes': sourceBytes,
    'chunkSize': encryptedReport.chunkSize,
    'chunkCount': encryptedReport.chunkCount,
    'encryptMilliseconds': encryptWatch.elapsedMilliseconds,
    'encryptMegabytesPerSecond': _megabytesPerSecond(
      sourceBytes,
      encryptWatch.elapsedMilliseconds,
    ),
    'decryptMilliseconds': decryptWatch.elapsedMilliseconds,
    'decryptMegabytesPerSecond': _megabytesPerSecond(
      sourceBytes,
      decryptWatch.elapsedMilliseconds,
    ),
    'baselineRssBytes': baselineRss,
    'peakRssBytes': peakRss,
    'rssDeltaBytes': peakRss - baselineRss,
    'uiTicks': ticks,
    'verified': verified,
    'wrongPassphraseMilliseconds': wrongPassphraseMilliseconds,
    'headerOnlyRejectMilliseconds': headerOnlyMilliseconds,
  };
}

Future<int> _rejectHeaderOnly(Directory directory, File encrypted) async {
  final input = encrypted.openSync();
  final Uint8List header;
  try {
    header = input.readSync(StreamingCryptoFormat.headerLength);
  } finally {
    input.closeSync();
  }
  final stripped = File('${directory.path}/header-only.bin')
    ..writeAsBytesSync(header);
  await _expectWrongPassphrase(stripped, File('${directory.path}/ignored.db'));
  final watch = Stopwatch()..start();
  await _expectWrongPassphrase(stripped, File('${directory.path}/ignored.db'));
  watch.stop();
  return watch.elapsedMilliseconds;
}

Future<int> _rejectFullFile(File encrypted, File destination) async {
  final watch = Stopwatch()..start();
  await _expectWrongPassphrase(encrypted, destination);
  watch.stop();
  return watch.elapsedMilliseconds;
}

Future<void> _expectWrongPassphrase(File encrypted, File destination) async {
  var rejected = false;
  try {
    await StreamingCryptoService().decryptStream(
      encrypted,
      'not-the-passphrase',
      destination,
    );
  } on StreamingCryptoException catch (error) {
    expect(error.code, 'WRONG_PASSPHRASE');
    rejected = true;
  }
  expect(rejected, isTrue);
}

void _writeSqlite(String path, int targetBytes) {
  final database = sql.sqlite3.open(path);
  database
    ..execute('PRAGMA journal_mode = OFF')
    ..execute('PRAGMA synchronous = OFF')
    ..execute('CREATE TABLE blob_store (id INTEGER PRIMARY KEY, payload BLOB)');
  final blobSize = targetBytes < 1024 * 1024 ? 32 * 1024 : 1024 * 1024;
  final payload = Uint8List(blobSize);
  for (var i = 0; i < payload.length; i++) {
    payload[i] = i & 0xff;
  }
  final statement = database.prepare(
    'INSERT INTO blob_store(payload) VALUES (?)',
  );
  database.execute('BEGIN');
  var stored = 0;
  while (stored < targetBytes) {
    statement.execute(<Object>[payload]);
    stored += payload.length;
  }
  database.execute('COMMIT');
  statement.close();
  database.close();
}

int _sqliteRowCount(String path) {
  final database = sql.sqlite3.open(path);
  final count = database.select('SELECT COUNT(*) AS c FROM blob_store').first['c'];
  database.close();
  return count! as int;
}

bool _filesEqual(File left, File right) {
  if (left.lengthSync() != right.lengthSync()) {
    return false;
  }
  final leftFile = left.openSync();
  final rightFile = right.openSync();
  try {
    final leftBytes = Uint8List(64 * 1024);
    final rightBytes = Uint8List(64 * 1024);
    while (true) {
      final leftCount = leftFile.readIntoSync(leftBytes);
      final rightCount = rightFile.readIntoSync(rightBytes);
      if (leftCount != rightCount) {
        return false;
      }
      if (leftCount == 0) {
        return true;
      }
      for (var i = 0; i < leftCount; i++) {
        if (leftBytes[i] != rightBytes[i]) {
          return false;
        }
      }
    }
  } finally {
    leftFile.closeSync();
    rightFile.closeSync();
  }
}

double _megabytesPerSecond(int bytes, int elapsedMilliseconds) {
  if (elapsedMilliseconds <= 0) {
    return 0;
  }
  return (bytes / (1024 * 1024)) / (elapsedMilliseconds / 1000);
}

void _writeResults(Map<String, Object?> payload) {
  final file = File('build/backup_benchmark_results.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
}

String _markdownTable(List<Map<String, Object?>> results) {
  final buffer = StringBuffer(
    '| Size | Encrypt MB/s | Decrypt MB/s | RSS delta MB | UI ticks |\n| --- | --- | --- | --- | --- |\n',
  );
  for (final row in results) {
    final deltaMb = ((row['rssDeltaBytes'] as int? ?? 0) / (1024 * 1024))
        .toStringAsFixed(2);
    final encrypt = (row['encryptMegabytesPerSecond'] as double? ?? 0)
        .toStringAsFixed(2);
    final decrypt = (row['decryptMegabytesPerSecond'] as double? ?? 0)
        .toStringAsFixed(2);
    buffer.writeln(
      '| ${row['sizeMb']}MB | $encrypt | $decrypt | $deltaMb | ${row['uiTicks']} |',
    );
  }
  return buffer.toString();
}

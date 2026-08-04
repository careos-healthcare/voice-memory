import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/disaster_recovery/disaster_recovery_core.dart';

void main() {
  group('DisasterRecoveryCore', () {
    test('round trips normalized journal, prefs, ledger, and audio', () async {
      final codec = _MemoryZipCodec();
      final core = DisasterRecoveryCore(zipCodec: codec);
      final source = _MemorySource(_sampleInputs());
      final sink = _MemorySink();

      final envelope = await core.export(
        passphrase: 'correct horse battery staple',
        source: source,
      );
      await core.import(
        envelopeBytes: envelope.toBytes(),
        passphrase: 'correct horse battery staple',
        sink: sink,
      );

      expect(sink.transaction.committed, isTrue);
      expect(sink.transaction.rolledBack, isFalse);
      expect(_describe(sink.transaction.staged), _describe(_sampleInputs()));
    });

    test('rejects a wrong passphrase before starting a transaction', () async {
      final core = DisasterRecoveryCore(zipCodec: _MemoryZipCodec());
      final envelope = await core.export(
        passphrase: 'right passphrase',
        source: _MemorySource(_sampleInputs()),
      );
      final sink = _MemorySink();

      await expectLater(
        core.import(
          envelopeBytes: envelope.toBytes(),
          passphrase: 'wrong passphrase',
          sink: sink,
        ),
        throwsA(isA<DisasterRecoveryAuthenticationException>()),
      );
      expect(sink.beginCount, 0);
    });

    test('rejects authenticated-envelope tampering', () async {
      final core = DisasterRecoveryCore(zipCodec: _MemoryZipCodec());
      final envelope = await core.export(
        passphrase: 'backup passphrase',
        source: _MemorySource(_sampleInputs()),
      );
      final json = Map<String, Object?>.from(
        jsonDecode(utf8.decode(envelope.toBytes())) as Map,
      );
      final ciphertext = base64Decode(json['ciphertext']! as String);
      ciphertext[ciphertext.length ~/ 2] ^= 0x01;
      json['ciphertext'] = base64Encode(ciphertext);

      await expectLater(
        core.import(
          envelopeBytes: utf8.encode(jsonEncode(json)),
          passphrase: 'backup passphrase',
          sink: _MemorySink(),
        ),
        throwsA(isA<DisasterRecoveryAuthenticationException>()),
      );
    });

    test('rejects traversal paths returned by the ZIP decoder', () async {
      final codec = _MemoryZipCodec(
        transformDecoded: (entries) {
          entries['../escape.json'] = Uint8List.fromList([1]);
          return entries;
        },
      );
      final core = DisasterRecoveryCore(zipCodec: codec);
      final envelope = await core.export(
        passphrase: 'backup passphrase',
        source: _MemorySource(_sampleInputs()),
      );

      await expectLater(
        core.import(
          envelopeBytes: envelope.toBytes(),
          passphrase: 'backup passphrase',
          sink: _MemorySink(),
        ),
        throwsA(isA<DisasterRecoveryPathException>()),
      );
    });

    test('declares secure-key exclusions and blocks reserved paths', () async {
      final codec = _MemoryZipCodec();
      final core = DisasterRecoveryCore(zipCodec: codec);

      await core.export(
        passphrase: 'backup passphrase',
        source: _MemorySource(_sampleInputs()),
      );
      final manifest = DisasterRecoveryManifest.fromBytes(
        codec.lastEncodedEntries![DisasterRecoveryManifest.archivePath]!,
      );
      expect(
        manifest.excludedData,
        containsAll(DisasterRecoveryExclusionPolicy.excludedData),
      );
      expect(
        manifest.entries.map((entry) => entry.kind.name),
        isNot(contains('secureKey')),
      );

      final unsafeInputs = [
        ..._sampleInputs(),
        RecoveryInput(
          kind: RecoveryDataKind.audio,
          logicalPath: 'secure_keys/exported.key',
          bytes: [7, 7, 7],
        ),
      ];
      await expectLater(
        core.export(
          passphrase: 'backup passphrase',
          source: _MemorySource(unsafeInputs),
        ),
        throwsA(isA<DisasterRecoveryFormatException>()),
      );
    });

    test('validates hashes after ZIP decoding', () async {
      final codec = _MemoryZipCodec(
        transformDecoded: (entries) {
          entries['data/audio/clips/sample.m4a'] = Uint8List.fromList([0]);
          return entries;
        },
      );
      final core = DisasterRecoveryCore(zipCodec: codec);
      final envelope = await core.export(
        passphrase: 'backup passphrase',
        source: _MemorySource(_sampleInputs()),
      );

      await expectLater(
        core.import(
          envelopeBytes: envelope.toBytes(),
          passphrase: 'backup passphrase',
          sink: _MemorySink(),
        ),
        throwsA(isA<DisasterRecoveryIntegrityException>()),
      );
    });

    test('rolls back when staging fails', () async {
      final core = DisasterRecoveryCore(zipCodec: _MemoryZipCodec());
      final envelope = await core.export(
        passphrase: 'backup passphrase',
        source: _MemorySource(_sampleInputs()),
      );
      final sink = _MemorySink(failAtStage: 2);

      await expectLater(
        core.import(
          envelopeBytes: envelope.toBytes(),
          passphrase: 'backup passphrase',
          sink: sink,
        ),
        throwsA(isA<StateError>()),
      );
      expect(sink.transaction.committed, isFalse);
      expect(sink.transaction.rolledBack, isTrue);
    });
  });
}

List<RecoveryInput> _sampleInputs() => [
  RecoveryInput(
    kind: RecoveryDataKind.journal,
    logicalPath: 'journal.json',
    bytes: utf8.encode('{"entries":[{"id":"one"}]}'),
  ),
  RecoveryInput(
    kind: RecoveryDataKind.preferences,
    logicalPath: 'preferences.json',
    bytes: utf8.encode('{"theme":"dark"}'),
  ),
  RecoveryInput(
    kind: RecoveryDataKind.ledger,
    logicalPath: 'ledger.json',
    bytes: utf8.encode('{"events":[1,2]}'),
  ),
  RecoveryInput(
    kind: RecoveryDataKind.audio,
    logicalPath: 'clips/sample.m4a',
    bytes: [0, 1, 2, 3, 255],
  ),
];

List<String> _describe(List<RecoveryInput> inputs) {
  final descriptions = inputs
      .map(
        (input) =>
            '${input.kind.name}:${input.logicalPath}:${base64Encode(input.bytes)}',
      )
      .toList(growable: false);
  descriptions.sort();
  return descriptions;
}

final class _MemorySource implements DisasterRecoverySource {
  _MemorySource(this.inputs);

  final List<RecoveryInput> inputs;

  @override
  Future<List<RecoveryInput>> readNormalizedInputs() async => inputs;
}

final class _MemorySink implements DisasterRecoverySink {
  _MemorySink({int? failAtStage})
    : transaction = _MemoryTransaction(failAtStage: failAtStage);

  final _MemoryTransaction transaction;
  int beginCount = 0;

  @override
  Future<DisasterRecoveryImportTransaction> beginStagedImport() async {
    beginCount += 1;
    return transaction;
  }
}

final class _MemoryTransaction implements DisasterRecoveryImportTransaction {
  _MemoryTransaction({this.failAtStage});

  final int? failAtStage;
  final List<RecoveryInput> staged = [];
  bool committed = false;
  bool rolledBack = false;

  @override
  Future<void> stage(RecoveryInput input) async {
    if (staged.length == failAtStage) {
      throw StateError('Injected staging failure.');
    }
    staged.add(input);
  }

  @override
  Future<void> commit() async {
    committed = true;
  }

  @override
  Future<void> rollback() async {
    rolledBack = true;
    staged.clear();
  }
}

typedef _DecodedTransform =
    Map<String, Uint8List> Function(Map<String, Uint8List> entries);

final class _MemoryZipCodec implements DisasterRecoveryZipCodec {
  _MemoryZipCodec({this.transformDecoded});

  final _DecodedTransform? transformDecoded;
  Map<String, Uint8List>? lastEncodedEntries;

  @override
  Future<Uint8List> encode(Map<String, Uint8List> entries) async {
    lastEncodedEntries = {
      for (final entry in entries.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          for (final entry in entries.entries)
            entry.key: base64Encode(entry.value),
        }),
      ),
    );
  }

  @override
  Future<Map<String, Uint8List>> decode(Uint8List zipBytes) async {
    final json = Map<String, Object?>.from(
      jsonDecode(utf8.decode(zipBytes)) as Map,
    );
    final entries = {
      for (final entry in json.entries)
        entry.key: Uint8List.fromList(base64Decode(entry.value! as String)),
    };
    return transformDecoded?.call(entries) ?? entries;
  }
}

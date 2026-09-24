import 'dart:io';

import 'package:archiveme_mobile/features/import/share_intent_handler.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/post_transcription_compressor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('raw audio is replaced and the wav file is removed', () async {
    final dir = Directory.systemTemp.createTempSync('opus-compress');
    addTearDown(() => dir.deleteSync(recursive: true));
    final raw = File('${dir.path}/note.wav')
      ..writeAsBytesSync(List<int>.filled(64, 7));
    final compressor = PostTranscriptionCompressor(
      compressOverride: ({required inputPath, required outputPath}) async {
        File(outputPath).writeAsBytesSync(const [1, 2, 3]);
        File(inputPath).deleteSync();
        return {'path': outputPath, 'codec': 'aac', 'discardedRaw': true};
      },
    );

    final stored = await compressor.compressAndDiscardRaw(raw);

    expect(stored.path, endsWith('note.m4a'));
    expect(stored.existsSync(), isTrue);
    expect(raw.existsSync(), isFalse);
    expect(PostTranscriptionCompressor.isRawAudio(File('clip.m4a')), isFalse);
  });

  test('a shared file is copied into the transcription queue', () async {
    final dir = Directory.systemTemp.createTempSync('share-import');
    addTearDown(() => dir.deleteSync(recursive: true));
    final imports = Directory('${dir.path}/imports')..createSync();
    final shared = File('${dir.path}/voice.wav')
      ..writeAsBytesSync(const [4, 5, 6]);
    const channel = MethodChannel(ShareIntentHandler.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'consumePendingImport') return shared.path;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final seen = <String>[];
    var compressed = false;
    final queue = ImportTranscriptionQueue()
      ..transcribe = (file) async {
        seen.add(file.path);
      };
    final compressor = PostTranscriptionCompressor(
      compressOverride: ({required inputPath, required outputPath}) async {
        compressed = true;
        File(outputPath).writeAsBytesSync(const [1]);
        if (File(inputPath).existsSync()) File(inputPath).deleteSync();
        return {'path': outputPath, 'codec': 'aac', 'discardedRaw': true};
      },
    );
    await ShareIntentHandler(
      channel: channel,
      queue: queue,
      compressor: compressor,
      importsDirectory: () async => imports,
      listenToLinks: false,
    ).start();

    expect(seen, hasLength(1));
    expect(seen.single, startsWith(imports.path));
    expect(seen.single, endsWith('voice.wav'));
    expect(File(seen.single).existsSync(), isFalse);
    expect(compressed, isTrue);
    expect(queue.pending, isEmpty);
  });

  test('an archiveme import link is transcribed and compressed', () async {
    final dir = Directory.systemTemp.createTempSync('share-link');
    addTearDown(() => dir.deleteSync(recursive: true));
    final imports = Directory('${dir.path}/imports')..createSync();
    final shared = File('${dir.path}/memo.wav')
      ..writeAsBytesSync(const [8, 9, 10]);
    const channel = MethodChannel('com.archiveme/share_import_link');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final seen = <String>[];
    final queue = ImportTranscriptionQueue()
      ..transcribe = (file) async {
        seen.add(file.path);
      };
    final handler = ShareIntentHandler(
      channel: channel,
      queue: queue,
      listenToLinks: false,
      importsDirectory: () async => imports,
      compressor: PostTranscriptionCompressor(
        compressOverride: ({required inputPath, required outputPath}) async {
          File(outputPath).writeAsBytesSync(const [1]);
          if (File(inputPath).existsSync()) File(inputPath).deleteSync();
          return {'path': outputPath, 'codec': 'aac', 'discardedRaw': true};
        },
      ),
    );
    await handler.start();
    await handler.acceptUri(
      Uri.parse(
        'archiveme://import?path=${Uri.encodeQueryComponent(shared.path)}',
      ),
    );

    expect(seen, hasLength(1));
    expect(seen.single, startsWith(imports.path));
    expect(File(seen.single).existsSync(), isFalse);
  });
}

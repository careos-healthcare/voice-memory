import 'dart:io';

import 'package:archiveme_mobile/features/import/sherpa_speech_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a wav import uses sherpa when the model files are present', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa-models');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/encoder.onnx').writeAsStringSync('encoder');
    File('${dir.path}/decoder.onnx').writeAsStringSync('decoder');
    File('${dir.path}/tokens.txt').writeAsStringSync('tokens');
    final wav = File('${dir.path}/note.wav')..writeAsBytesSync(const [1, 2]);

    final seen = <String>[];
    var fallbacks = 0;
    final queue = SherpaSpeechQueue(
      modelDirectory: () async => dir,
      recognizeWav: (path, models) async {
        seen.add(path);
        expect(models.encoder, endsWith('encoder.onnx'));
        expect(models.decoder, endsWith('decoder.onnx'));
        expect(models.tokens, endsWith('tokens.txt'));
        return 'the rent is due';
      },
      fallback: (file) async {
        fallbacks += 1;
      },
    );

    final movie = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [3]);
    await queue.enqueue(wav);
    await queue.enqueue(movie);

    expect(seen, [wav.path]);
    expect(fallbacks, 1);
  });

  test('missing models and non-wav files use the speech worker', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa-missing');
    addTearDown(() => dir.deleteSync(recursive: true));
    final wav = File('${dir.path}/note.wav')..writeAsBytesSync(const [1]);
    final movie = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [2]);
    final seen = <String>[];
    final queue = SherpaSpeechQueue(
      modelDirectory: () async => Directory('${dir.path}/absent'),
      recognizeWav: (path, models) async => 'unused',
      fallback: (file) async {
        seen.add(file.path);
      },
    );

    await queue.enqueue(wav);
    await queue.enqueue(movie);

    expect(seen, [wav.path, movie.path]);
  });

  test('imports run one at a time', () async {
    final dir = Directory.systemTemp.createTempSync('sherpa-serial');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in ['encoder.onnx', 'decoder.onnx', 'tokens.txt']) {
      File('${dir.path}/$name').writeAsStringSync(name);
    }
    final first = File('${dir.path}/a.wav')..writeAsBytesSync(const [1]);
    final second = File('${dir.path}/b.wav')..writeAsBytesSync(const [2]);
    final order = <String>[];
    var active = 0;
    var peak = 0;
    final queue = SherpaSpeechQueue(
      modelDirectory: () async => dir,
      recognizeWav: (path, models) async {
        active += 1;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        order.add(path);
        active -= 1;
        return 'ok';
      },
    );

    await Future.wait([queue.enqueue(first), queue.enqueue(second)]);

    expect(peak, 1);
    expect(order, [first.path, second.path]);
  });
}

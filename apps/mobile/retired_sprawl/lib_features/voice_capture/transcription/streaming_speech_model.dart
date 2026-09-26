import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// On-device streaming Zipformer files. Nothing here leaves the phone.
class StreamingSpeechModel {
  const StreamingSpeechModel({required this.directory});

  static const downloadingLabel = 'Downloading the on-device speech model';

  /// English streaming Zipformer published by the sherpa-onnx project.
  static const modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2';

  static const fileNames = [
    'encoder.onnx',
    'decoder.onnx',
    'joiner.onnx',
    'tokens.txt',
  ];

  final Directory directory;

  bool get isReady => fileNames.every((name) {
    final file = File(p.join(directory.path, name));
    return file.existsSync() && file.lengthSync() > 0;
  });

  String pathFor(String name) => p.join(directory.path, name);
}

/// Downloads the streaming model into app support on a Wi-Fi connection.
class StreamingSpeechModelStore {
  StreamingSpeechModelStore({
    required this.supportDirectory,
    this.wifiOnly = true,
    this.onWifi,
    this.fetch,
  });

  final Future<Directory> Function() supportDirectory;
  final bool wifiOnly;
  final Future<bool> Function()? onWifi;
  final Future<Uint8List> Function(
    void Function(int received, int total) onProgress,
  )?
  fetch;

  /// Returns the model directory when the files are already here or the
  /// download finished. Returns null when Wi-Fi is required and absent.
  Future<Directory?> ensure({
    void Function(String message)? onStatus,
  }) async {
    final root = Directory(
      p.join((await supportDirectory()).path, 'streaming_zipformer_en'),
    );
    final model = StreamingSpeechModel(directory: root);
    if (model.isReady) return root;
    final connected = onWifi;
    if (wifiOnly && connected != null && !await connected()) return null;
    final download = fetch;
    if (download == null) return null;
    onStatus?.call(StreamingSpeechModel.downloadingLabel);
    if (!root.existsSync()) root.createSync(recursive: true);
    final bytes = await download((received, total) {
      onStatus?.call(StreamingSpeechModel.downloadingLabel);
    });
    _unpack(bytes, root);
    return model.isReady ? root : null;
  }

  void _unpack(Uint8List bytes, Directory root) {
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = p.basename(file.name);
      final stored = _storedName(name);
      if (stored == null) continue;
      final out = File(p.join(root.path, stored));
      out.writeAsBytesSync(file.content as List<int>);
    }
  }

  String? _storedName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('encoder') && lower.endsWith('.onnx')) {
      return 'encoder.onnx';
    }
    if (lower.contains('decoder') && lower.endsWith('.onnx')) {
      return 'decoder.onnx';
    }
    if (lower.contains('joiner') && lower.endsWith('.onnx')) {
      return 'joiner.onnx';
    }
    if (lower == 'tokens.txt') return 'tokens.txt';
    return null;
  }
}

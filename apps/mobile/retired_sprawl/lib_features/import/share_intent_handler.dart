import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:archiveme_mobile/features/import/sherpa_speech_queue.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/post_transcription_compressor.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Files waiting for on-device transcription after a share-sheet import.
class ImportTranscriptionQueue {
  final List<File> pending = [];

  /// Local transcription job. Production passes the on-device audio pipeline.
  Future<void> Function(File file)? transcribe;

  Future<void> enqueue(File file) async {
    final job = transcribe;
    if (job == null) {
      pending.add(file);
      return;
    }
    await job(file);
  }
}

/// Shared queue used when a shared file arrives while the shell is mounted.
final importTranscriptionQueue = ImportTranscriptionQueue();

/// Receives an audio or video file shared into the app and queues it.
class ShareIntentHandler {
  ShareIntentHandler({
    MethodChannel? channel,
    ImportTranscriptionQueue? queue,
    PostTranscriptionCompressor? compressor,
    this.importsDirectory,
    Stream<Uri>? linkStream,
    this.listenToLinks = true,
  }) : _channel = channel ?? const MethodChannel(channelName),
       queue = queue ?? importTranscriptionQueue,
       _compressor = compressor ?? PostTranscriptionCompressor(),
       _linkStream = linkStream;

  static const channelName = 'com.archiveme/share_import';

  final MethodChannel _channel;
  final ImportTranscriptionQueue queue;
  final PostTranscriptionCompressor _compressor;
  final Future<Directory> Function()? importsDirectory;
  final Stream<Uri>? _linkStream;
  final bool listenToLinks;
  final Set<String> _accepted = {};
  StreamSubscription<Uri>? _links;
  var _listening = false;

  Future<void> start() async {
    if (_listening) return;
    _listening = true;
    queue.transcribe ??= SherpaSpeechQueue.instance.enqueue;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shareImportReady') return;
      final path = call.arguments?.toString();
      if (path == null || path.isEmpty) return;
      await _accept(path);
    });
    _listenForLinks();
    try {
      final pending = await _channel.invokeMethod<String>(
        'consumePendingImport',
      );
      if (pending != null && pending.isNotEmpty) {
        await _accept(pending);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void _listenForLinks() {
    if (!listenToLinks) return;
    unawaited(_links?.cancel());
    final injected = _linkStream;
    if (injected != null) {
      _links = injected.listen((uri) {
        unawaited(acceptUri(uri));
      });
      return;
    }
    try {
      _links = AppLinks().uriLinkStream.listen(
        (uri) {
          unawaited(acceptUri(uri));
        },
        onError: (Object _) {},
      );
    } on Object {
      return;
    }
  }

  /// Accepts `archiveme://import?path=` and file URLs from Open In.
  Future<void> acceptUri(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'archiveme' && uri.host.toLowerCase() == 'import') {
      final path = uri.queryParameters['path'];
      if (path == null || path.isEmpty) return;
      await _accept(path);
      return;
    }
    if (scheme == 'file') {
      await _accept(uri.toFilePath());
    }
  }

  Future<void> _accept(String path) async {
    final source = File(path);
    if (!source.existsSync()) return;
    final key =
        '${source.absolute.path}:${source.lengthSync()}:${source.lastModifiedSync().microsecondsSinceEpoch}';
    if (!_accepted.add(key)) return;
    final stored = await _copyIntoImports(source);
    final job = queue.transcribe;
    if (job == null) {
      queue.pending.add(stored);
      return;
    }
    await job(stored);
    await _compressor.compressAndDiscardRaw(stored);
  }

  Future<File> _copyIntoImports(File source) async {
    final directory = await _resolveImports();
    final target = File(p.join(directory.path, p.basename(source.path)));
    if (source.absolute.path == target.absolute.path) return source;
    if (target.existsSync()) {
      final unique = File(
        p.join(
          directory.path,
          '${p.basenameWithoutExtension(source.path)}-${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}',
        ),
      );
      return source.copy(unique.path);
    }
    return source.copy(target.path);
  }

  Future<Directory> _resolveImports() async {
    final override = importsDirectory;
    if (override != null) {
      final directory = await override();
      await directory.create(recursive: true);
      return directory;
    }
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory(p.join(root.path, 'imports'));
      await directory.create(recursive: true);
      return directory;
    } on Object {
      final directory = Directory(
        p.join(Directory.systemTemp.path, 'archiveme_imports'),
      );
      await directory.create(recursive: true);
      return directory;
    }
  }
}

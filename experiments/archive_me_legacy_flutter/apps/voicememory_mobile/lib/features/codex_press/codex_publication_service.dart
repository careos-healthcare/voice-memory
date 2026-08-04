import 'dart:io';
import 'dart:typed_data';

import '../../storage/encrypted_json_file_store.dart';
import 'codex_compiler.dart';
import 'codex_encryption_manager.dart';
import 'codex_models.dart';
import 'codex_renderers.dart';

typedef CodexOwnerAuthenticator = Future<bool> Function(String reason);

final class CodexExportRecord {
  const CodexExportRecord({
    required this.id,
    required this.title,
    required this.format,
    required this.createdAt,
    required this.size,
    required this.encrypted,
  });

  final String id;
  final String title;
  final CodexExportFormat format;
  final DateTime createdAt;
  final int size;
  final bool encrypted;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'format': format.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'size': size,
    'encrypted': encrypted,
  };

  factory CodexExportRecord.fromJson(Map<String, Object?> json) =>
      CodexExportRecord(
        id: json['id']! as String,
        title: json['title']! as String,
        format: CodexExportFormat.values.byName(json['format']! as String),
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        size: (json['size']! as num).toInt(),
        encrypted: json['encrypted']! as bool,
      );
}

final class CodexPublicationHistoryStore {
  const CodexPublicationHistoryStore(this._store);
  final EncryptedJsonFileStore _store;

  Future<List<CodexExportRecord>> list() async {
    final raw = await _store.readJson();
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => CodexExportRecord.fromJson(Map<String, Object?>.from(item)),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> add(CodexExportRecord record) async {
    final records = [...await list()];
    records.insert(0, record);
    await _store.writeJson(
      records.take(100).map((item) => item.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    if (await _store.file.exists()) await _store.file.delete();
  }
}

final class CodexPublicationService {
  CodexPublicationService({
    required this.compiler,
    required this.renderer,
    required this.encryptionManager,
    required this.history,
    required this.exportsDirectory,
    required this.authenticateOwner,
  });

  final CodexCompiler compiler;
  final CodexRenderer renderer;
  final CodexEncryptionManager encryptionManager;
  final CodexPublicationHistoryStore history;
  final Directory exportsDirectory;
  final CodexOwnerAuthenticator authenticateOwner;

  CodexCancellation? _activeCancellation;

  Future<List<CodexSourceOption>> sourceOptions() =>
      compiler.listSourceOptions();

  Future<CodexManuscript> compile(
    CodexCompilationRequest request, {
    void Function(String stage, double progress)? onProgress,
  }) async {
    _activeCancellation?.cancel();
    final cancellation = CodexCancellation();
    _activeCancellation = cancellation;
    try {
      onProgress?.call('Reading local memories', 0.1);
      final manuscript = await compiler.compile(
        request,
        cancellation: cancellation,
      );
      onProgress?.call('Manuscript ready', 1);
      return manuscript;
    } finally {
      if (identical(_activeCancellation, cancellation)) {
        _activeCancellation = null;
      }
    }
  }

  Future<File> exportEncrypted({
    required CodexManuscript manuscript,
    required String? password,
    required bool includeRecoverySlot,
    void Function(String stage, double progress)? onProgress,
  }) async {
    onProgress?.call('Typesetting private formats', 0.25);
    final artifacts = await renderer.render(manuscript);
    onProgress?.call('Encrypting Codex package', 0.65);
    final bytes = await encryptionManager.encrypt(
      manuscript: manuscript,
      artifacts: artifacts,
      password: password,
      includeRecoverySlot: includeRecoverySlot,
    );
    final record = await _write(
      manuscript: manuscript,
      format: CodexExportFormat.codex,
      extension: 'codex',
      bytes: bytes,
      encrypted: true,
    );
    onProgress?.call('Encrypted Codex ready', 1);
    return record;
  }

  Future<File> exportPlaintext({
    required CodexManuscript manuscript,
    required CodexExportFormat format,
    required bool warningAccepted,
  }) async {
    if (format == CodexExportFormat.codex || !warningAccepted) {
      throw const FormatException(
        'Plaintext export requires an explicit warning acknowledgement.',
      );
    }
    final authorized = await authenticateOwner(
      'Authorize plaintext ${format.name.toUpperCase()} memoir export',
    );
    if (!authorized) throw const CodexAuthenticationException();
    final rendered = await renderer.render(manuscript);
    final bytes = switch (format) {
      CodexExportFormat.pdf => rendered.pdf,
      CodexExportFormat.epub => rendered.epub,
      CodexExportFormat.offlineHtml => rendered.offlineHtml,
      CodexExportFormat.codex => throw StateError('Encrypted format required.'),
    };
    return _write(
      manuscript: manuscript,
      format: format,
      extension: format == CodexExportFormat.offlineHtml ? 'html' : format.name,
      bytes: bytes,
      encrypted: false,
    );
  }

  void cancel() => _activeCancellation?.cancel();

  Future<void> onLockOrRestore() async {
    cancel();
    await purgeTemporaryArtifacts();
  }

  Future<void> purgeTemporaryArtifacts() async {
    if (!await exportsDirectory.exists()) return;
    await for (final entity in exportsDirectory.list()) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  Future<void> wipe() async {
    cancel();
    await history.clear();
    if (await exportsDirectory.exists()) {
      await exportsDirectory.delete(recursive: true);
    }
  }

  Future<File> _write({
    required CodexManuscript manuscript,
    required CodexExportFormat format,
    required String extension,
    required List<int> bytes,
    required bool encrypted,
  }) async {
    await exportsDirectory.create(recursive: true);
    final name = _safeName(manuscript.title);
    final stamp = manuscript.generatedAt.millisecondsSinceEpoch;
    final destination = File(
      '${exportsDirectory.path}/${name}_$stamp.$extension',
    );
    final temporary = File('${destination.path}.part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
      await history.add(
        CodexExportRecord(
          id: '${manuscript.id}-${format.name}-$stamp',
          title: manuscript.title,
          format: format,
          createdAt: manuscript.generatedAt,
          size: bytes.length,
          encrypted: encrypted,
        ),
      );
      return destination;
    } finally {
      if (await temporary.exists()) {
        await temporary.writeAsBytes(Uint8List(0), flush: true);
        await temporary.delete();
      }
    }
  }

  static String _safeName(String title) {
    final value = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return value.isEmpty
        ? 'private-codex'
        : value.substring(0, value.length.clamp(1, 60));
  }
}

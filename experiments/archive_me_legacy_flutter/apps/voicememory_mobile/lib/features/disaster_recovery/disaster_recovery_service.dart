import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/app_services.dart';
import 'app_disaster_recovery_adapter.dart';
import 'archive_disaster_recovery_zip_codec.dart';
import 'disaster_recovery_core.dart';

typedef RecoveryShareFile = Future<void> Function(String path);
typedef RecoveryPickFile = Future<List<int>?> Function();

final class DisasterRecoveryService {
  DisasterRecoveryService({
    DisasterRecoveryCore? core,
    this.shareFile,
    this.pickFile,
  }) : _core =
           core ??
           DisasterRecoveryCore(
             zipCodec: const ArchiveDisasterRecoveryZipCodec(),
           );

  final DisasterRecoveryCore _core;
  final RecoveryShareFile? shareFile;
  final RecoveryPickFile? pickFile;

  Future<void> export({required String passphrase}) async {
    final services = AppServices.instance;
    final envelope = await _core.export(
      passphrase: passphrase,
      source: AppDisasterRecoverySource(
        journal: services.journalStore,
        prefs: services.prefs,
        ledger: services.transcriptionLedger,
      ),
    );
    final temp = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
    final file = File('${temp.path}/archiveme_recovery_$stamp.amrecover');
    try {
      await file.writeAsBytes(envelope.toBytes(), flush: true);
      final share =
          shareFile ??
          (path) => Share.shareXFiles([
            XFile(path, mimeType: 'application/octet-stream'),
          ], subject: 'ArchiveMe encrypted recovery archive');
      await share(file.path);
    } finally {
      if (await file.exists()) {
        await file.writeAsBytes(const [], flush: true);
        await file.delete();
      }
    }
  }

  Future<bool> pickAndImport({required String passphrase}) async {
    final bytes = await (pickFile ?? _defaultPick)();
    if (bytes == null) return false;
    await importBytes(bytes, passphrase: passphrase);
    return true;
  }

  Future<void> importBytes(
    List<int> bytes, {
    required String passphrase,
  }) async {
    final services = AppServices.instance;
    final executor = services.transcriptionQueueExecutor;
    executor.pause();
    try {
      await _core.import(
        envelopeBytes: bytes,
        passphrase: passphrase,
        sink: AppDisasterRecoverySink(
          journal: services.journalStore,
          prefs: services.prefs,
          ledger: services.transcriptionLedger,
        ),
      );
    } finally {
      executor.resume();
      unawaited(executor.drain());
    }
  }

  static Future<List<int>?> _defaultPick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['amrecover'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.bytes != null) return picked.bytes;
    final pickedPath = picked.path;
    return pickedPath == null ? null : File(pickedPath).readAsBytes();
  }
}

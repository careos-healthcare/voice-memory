import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:path/path.dart' as p;

/// Structured account export for data-trust / portability (JSON + Markdown ZIP).
class AccountPortabilityManifest {
  const AccountPortabilityManifest({
    required this.exportedAt,
    required this.entryCount,
    required this.files,
    required this.trustFooter,
  });

  final DateTime exportedAt;
  final int entryCount;
  final List<String> files;
  final String trustFooter;

  Map<String, dynamic> toJson() => {
    'format': 'archiveme-account-portability',
    'version': 1,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'entryCount': entryCount,
    'trustFooter': trustFooter,
    'files': files,
  };
}

class AccountPortabilityResult {
  const AccountPortabilityResult({
    required this.zipBytes,
    required this.manifest,
    required this.suggestedFileName,
  });

  final Uint8List zipBytes;
  final AccountPortabilityManifest manifest;
  final String suggestedFileName;
}

class AccountDataPortabilityService {
  AccountDataPortabilityService({
    required JournalStore journalStore,
    MobilePrefsStore? prefsStore,
    PrivateDataService? privateDataService,
  }) : _journal = journalStore,
       _prefs = prefsStore,
       _privateData =
           privateDataService ?? PrivateDataService(journalStore: journalStore);

  static const trustFooter =
      'Exported from your device. Your own voice — not therapy or diagnosis.';

  final JournalStore _journal;
  final MobilePrefsStore? _prefs;
  final PrivateDataService _privateData;

  Future<AccountPortabilityResult> buildZipExport() async {
    // An export is the whole archive in one file — outside every per-stream
    // scope a caregiver can be granted.
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.exportAccountPortability,
    );
    final entries = await _journal.loadAll();
    final exportedAt = DateTime.now().toUtc();
    final sanitized = await _privateData.buildSanitizedExport();
    final exportPack = ArchiveExportPackEngine.build(entries: entries);
    final evidenceTrails = await _readEvidenceTrails();

    final archiveJson = <String, dynamic>{
      'format': 'archiveme-account-portability',
      'version': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'entryCount': entries.length,
      'entries': sanitized.entries,
      'archiveExportPack': exportPack.toJson(),
      'evidenceTrails': evidenceTrails,
      'trustFooter': trustFooter,
    };

    final markdown = _buildMarkdown(
      entries: entries,
      exportPack: exportPack,
      exportedAt: exportedAt,
    );
    final readme = _buildReadme(
      entryCount: entries.length,
      exportedAt: exportedAt,
    );

    final manifest = AccountPortabilityManifest(
      exportedAt: exportedAt,
      entryCount: entries.length,
      files: const [
        'README.md',
        'manifest.json',
        'archive.json',
        'archive.md',
      ],
      trustFooter: trustFooter,
    );

    final readmeBytes = utf8.encode(readme);
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    final archiveJsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(archiveJson),
    );
    final markdownBytes = utf8.encode(markdown);

    final archive = Archive()
      ..addFile(ArchiveFile('README.md', readmeBytes.length, readmeBytes))
      ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile('archive.json', archiveJsonBytes.length, archiveJsonBytes))
      ..addFile(ArchiveFile('archive.md', markdownBytes.length, markdownBytes));

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final stamp = exportedAt.toIso8601String().substring(0, 10);
    return AccountPortabilityResult(
      zipBytes: zipBytes,
      manifest: manifest,
      suggestedFileName: 'archiveme-account-export-$stamp.zip',
    );
  }

  Future<Map<String, dynamic>> _readEvidenceTrails() async {
    final prefs = _prefs;
    if (prefs == null) return const {};

    const keys = [
      'archiveFacts',
      'archiveInsightFeedbackRecords',
      'archiveWatchlistItems',
      'archiveChangeTimelineMetrics',
      'helped_tracking_records_v1',
      'what_changed_v2_records_v1',
    ];

    final trails = <String, dynamic>{};
    for (final key in keys) {
      final value = await prefs.readMap(key);
      if (value != null && value.isNotEmpty) {
        trails[key] = value;
      }
    }
    return trails;
  }

  String _buildReadme({
    required int entryCount,
    required DateTime exportedAt,
  }) {
    return '''
# ArchiveMe Account Export

Exported: ${exportedAt.toUtc().toIso8601String()}
Entries: $entryCount

$trustFooter

## Files in this archive

- `manifest.json` — export metadata
- `archive.json` — structured JSON (entries, export pack, evidence trails)
- `archive.md` — human-readable Markdown reflections

Store this ZIP where you trust. ArchiveMe does not upload exports to any server.
''';
  }

  String _buildMarkdown({
    required List<JournalEntry> entries,
    required ArchiveExportPack exportPack,
    required DateTime exportedAt,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ArchiveMe Archive')
      ..writeln()
      ..writeln('Exported: ${exportedAt.toUtc().toIso8601String()}')
      ..writeln('Reflections: ${entries.length}')
      ..writeln()
      ..writeln(trustFooter)
      ..writeln()
      ..writeln('---')
      ..writeln();

    if (exportPack.currentBeliefLine != null &&
        exportPack.currentBeliefLine!.trim().isNotEmpty) {
      buffer
        ..writeln('## Current belief')
        ..writeln()
        ..writeln(exportPack.currentBeliefLine!.trim())
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    if (exportPack.evidenceMapSummary.isNotEmpty) {
      buffer
        ..writeln('## Evidence map')
        ..writeln();
      for (final row in exportPack.evidenceMapSummary) {
        buffer.writeln('- $row');
      }
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    buffer.writeln('## Reflections');
    buffer.writeln();

    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final entry in sorted) {
      final transcript = UserContentSafety.sanitizePlainText(entry.transcript);
      final observation = UserContentSafety.sanitizePlainText(
        entry.reflection.concreteObservation,
      );
      buffer
        ..writeln('### ${entry.createdAt.toUtc().toIso8601String()}')
        ..writeln();
      // Omitted entirely when unread — an export is evidence, so a blank mood
      // or an "0/10" intensity would read as a measurement that was taken.
      final moodLine = <String>[
        if (entry.reflection.mood.trim().isNotEmpty)
          '**Mood:** ${entry.reflection.mood.trim()}',
        if (entry.reflection.emotionalIntensity > 0)
          '**Intensity:** ${entry.reflection.emotionalIntensity}/10',
      ];
      if (moodLine.isNotEmpty) {
        buffer.writeln(moodLine.join(' · '));
      }
      if (entry.reflection.recurringThemes.isNotEmpty) {
        buffer.writeln(
          '**Themes:** ${entry.reflection.recurringThemes.join(', ')}',
        );
      }
      buffer.writeln();
      if (transcript.trim().isNotEmpty) {
        buffer
          ..writeln('**Transcript**')
          ..writeln()
          ..writeln(transcript.trim())
          ..writeln();
      }
      if (observation.trim().isNotEmpty) {
        buffer
          ..writeln('**Observation**')
          ..writeln()
          ..writeln(observation.trim())
          ..writeln();
      }
      buffer
        ..writeln('---')
        ..writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<File> writeZipToTempFile(AccountPortabilityResult result) async {
    final dir = Directory.systemTemp.createTempSync('archiveme_export_');
    final file = File(p.join(dir.path, result.suggestedFileName));
    await file.writeAsBytes(result.zipBytes, flush: true);
    return file;
  }
}
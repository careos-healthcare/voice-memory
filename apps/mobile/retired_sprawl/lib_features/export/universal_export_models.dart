import 'dart:io';

/// One journal moment prepared for a full archive export.
class UniversalExportEntry {
  const UniversalExportEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    this.updatedAt,
    this.tags = const [],
    this.location = '',
    this.audioPath,
    this.metadata = const {},
  });

  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String transcript;
  final List<String> tags;
  final String location;
  final String? audioPath;
  final Map<String, Object?> metadata;
}

/// Inputs for a full archive export.
class UniversalExportRequest {
  const UniversalExportRequest({
    required this.entries,
    required this.databaseFile,
    required this.outputDirectory,
  });

  final List<UniversalExportEntry> entries;
  final File databaseFile;
  final Directory outputDirectory;
}

/// Uncompressed size of the archive, measured before zip compression.
class ExportSizeEstimate {
  const ExportSizeEstimate({
    required this.markdownBytes,
    required this.databaseBytes,
    required this.audioBytes,
    required this.sidecarBytes,
    required this.entryCount,
    required this.recordingCount,
  });

  final int markdownBytes;
  final int databaseBytes;
  final int audioBytes;
  final int sidecarBytes;
  final int entryCount;
  final int recordingCount;

  int get totalBytes =>
      markdownBytes + databaseBytes + audioBytes + sidecarBytes;
}

/// How far a running export has gotten.
class UniversalExportProgress {
  const UniversalExportProgress({
    required this.label,
    required this.fraction,
  });

  final String label;
  final double fraction;
}

/// Share the zip, or leave it in the output directory.
enum UniversalExportDelivery { share, save }

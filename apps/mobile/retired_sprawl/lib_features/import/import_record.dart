import 'package:archiveme_mobile/features/import/import_source.dart';

/// One parsed row from an external export before JournalEntry conversion.
class ExternalImportRecord {
  const ExternalImportRecord({
    required this.source,
    required this.sourceFile,
    required this.text,
    this.createdAt,
    this.externalId,
  });

  final ExternalImportSource source;
  final String sourceFile;
  final String text;
  final DateTime? createdAt;
  final String? externalId;
}
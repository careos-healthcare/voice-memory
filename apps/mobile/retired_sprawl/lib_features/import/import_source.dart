/// External journal sources supported by the mobile import pipeline.
enum ExternalImportSource {
  dayOneJson,
  appleNotesJson,
  appleNotesCsv,
  plainText,
}

extension ExternalImportSourceLabels on ExternalImportSource {
  String get label => switch (this) {
        ExternalImportSource.dayOneJson => 'Day One (JSON)',
        ExternalImportSource.appleNotesJson => 'Apple Notes (JSON)',
        ExternalImportSource.appleNotesCsv => 'Apple Notes (CSV)',
        ExternalImportSource.plainText => 'Plain text',
      };
}
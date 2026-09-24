import 'package:archiveme_mobile/features/archive_theory/archive_theory_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Saved page plus the moments that let the archive engine score it.
class ArchiveTemplateDraft {
  const ArchiveTemplateDraft({
    required this.template,
    required this.page,
    required this.moments,
    required this.pattern,
  });

  final ArchiveEntryTemplate template;
  final JournalEntry page;
  final List<JournalEntry> moments;

  /// Non-null when the template clears the archive engine's visibility bar.
  final ArchiveCurrentTheory? pattern;

  List<JournalEntry> get entries => [page, ...moments];

  List<String> get evidenceEntryIds => [
    for (final entry in entries) entry.id,
  ];
}

/// Turns a template into journal rows and scores them immediately.
abstract final class ArchiveTemplateMaterializer {
  ArchiveTemplateMaterializer._();

  static const captureSource = 'archive_template';

  static ArchiveTemplateDraft materialize(
    ArchiveEntryTemplate template, {
    DateTime? now,
    ArchiveTheoryEngine engine = const ArchiveTheoryEngine(),
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    final moments = <JournalEntry>[
      for (var i = 0; i < template.supportingMoments.length; i++)
        _entry(
          id: template.momentEntryId(i),
          createdAt: clock.subtract(
            Duration(days: template.supportingMoments.length - i),
          ),
          transcript: template.supportingMoments[i],
          template: template,
        ),
    ];
    final page = _entry(
      id: template.pageEntryId,
      createdAt: clock,
      transcript: template.pageBody,
      template: template,
    );
    final entries = [page, ...moments];
    return ArchiveTemplateDraft(
      template: template,
      page: page,
      moments: moments,
      pattern: engine.build(
        entries: entries,
        statement: template.patternStatement,
        lastUpdated: clock,
      ),
    );
  }

  static JournalEntry _entry({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required ArchiveEntryTemplate template,
  }) {
    return JournalEntry.stored(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: transcript.length < 12 ? 1 : transcript.length ~/ 12,
      reflection: Reflection(
        mood: 'calm',
        emotionalIntensity: 4,
        recurringThemes: const ['daily'],
        exactLanguagePattern: template.patternStatement,
        concreteObservation: template.patternStatement,
        repeatedSignal: template.title,
      ),
      sync: JournalSyncMetadata(createdAt: createdAt, entryId: id),
      display: JournalDisplayMetadata(
        captureSource: captureSource,
        captureContextTag: template.id,
      ),
      proof: const JournalProofData(),
    );
  }
}

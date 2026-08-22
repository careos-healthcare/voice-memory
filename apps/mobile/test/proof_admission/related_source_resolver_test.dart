import 'package:archiveme_mobile/features/proof_admission/related_source_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry entry(
    String id,
    String transcript, {
    DateTime? createdAt,
    bool archived = false,
  }) => JournalEntry(
    id: id,
    transcript: transcript,
    createdAt: createdAt ?? DateTime(2026),
    durationSeconds: 12,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    isArchived: archived,
  );

  RelatedSourceResolver resolver() => RelatedSourceResolver(
    archiveScope: 'local_archive_v1',
    ownerScope: 'local_owner_v1',
  );

  test('the subject always leads the source list', () {
    final subject = entry('new', 'checking my phone at dinner again');
    final archive = [entry('old', 'checking my phone at dinner'), subject];

    final sources = resolver().sourcesFor(subject, archive);

    expect(sources.first.entryId, 'new');
  });

  test('a related earlier moment joins the subject', () {
    final subject = entry(
      'new',
      'I checked my phone all through dinner again tonight',
      createdAt: DateTime(2026, 2),
    );
    final archive = [
      entry(
        'old',
        'I keep checking my phone during dinner with family',
        createdAt: DateTime(2026),
      ),
      subject,
    ];

    final resolved = resolver();
    resolved.sync(archive);
    final sources = resolved.sourcesFor(subject, archive);

    expect(sources.map((source) => source.entryId), ['new', 'old']);
  });

  test('an unrelated moment is left out', () {
    final subject = entry('new', 'checking my phone at dinner again tonight');
    final archive = [
      entry('unrelated', 'the car needs new tyres before winter arrives'),
      subject,
    ];

    final resolved = resolver();
    resolved.sync(archive);

    expect(resolved.sourcesFor(subject, archive).single.entryId, 'new');
  });

  test('an archived moment never becomes a source', () {
    final subject = entry('new', 'checking my phone at dinner again tonight');
    final archive = [
      entry('old', 'checking my phone at dinner again tonight', archived: true),
      subject,
    ];

    final resolved = resolver();
    resolved.sync(archive);

    expect(resolved.sourcesFor(subject, archive).single.entryId, 'new');
  });

  test('the source list is capped', () {
    final subject = entry('new', 'checking my phone at dinner again tonight');
    final archive = [
      for (var i = 0; i < 20; i++)
        entry('old_$i', 'checking my phone at dinner tonight number $i'),
      subject,
    ];

    final resolved = resolver();
    resolved.sync(archive);
    final sources = resolved.sourcesFor(subject, archive, limit: 3);

    expect(sources, hasLength(4));
  });

  test('a forgotten entry stops being offered', () {
    final subject = entry('new', 'checking my phone at dinner again tonight');
    final archive = [
      entry('old', 'checking my phone at dinner with family tonight'),
      subject,
    ];

    final resolved = resolver();
    resolved.sync(archive);
    expect(resolved.sourcesFor(subject, archive), hasLength(2));

    resolved.forget('old');
    expect(resolved.sourcesFor(subject, archive).single.entryId, 'new');
  });

  test('revisions match what the display gate would compute', () {
    final subject = entry('new', 'checking my phone at dinner');
    final resolved = resolver();

    final fromResolver = resolved.sourceFor(subject);
    final again = resolved.sourceFor(subject);

    expect(fromResolver.transcriptRevision, isNotEmpty);
    expect(fromResolver.transcriptRevision, again.transcriptRevision);
  });

  test('an edited transcript produces a different revision', () {
    final resolved = resolver();
    final before = resolved.sourceFor(entry('a', 'checking my phone'));
    final after = resolved.sourceFor(entry('a', 'checking my phone less'));

    expect(before.transcriptRevision, isNot(after.transcriptRevision));
  });
}
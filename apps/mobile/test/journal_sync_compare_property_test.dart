import 'dart:math';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:glados/glados.dart';
import 'package:uuid/uuid.dart';

Reflection _neutralReflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

JournalEntry _entryWith({
  required int revision,
  required DateTime updatedAt,
  required String changeId,
  String? id,
}) {
  return JournalEntry(
    id: id ?? 'entry-${revision}-${changeId.hashCode}',
    createdAt: DateTime.utc(2026),
    transcript: 'transcript',
    durationSeconds: 1,
    reflection: _neutralReflection(),
    revision: revision,
    updatedAt: updatedAt,
    changeId: changeId,
  );
}

String _randomChangeId(Random random) {
  final hex = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${const Uuid().v4()}-$hex';
}

JournalEntry _randomEntry(Random random, int size) {
  final revision = random.nextInt(size.clamp(1, 100)) + 1;
  final millis = random.nextInt(1_000_000);
  final updatedAt = DateTime.utc(2026).add(Duration(milliseconds: millis));
  return _entryWith(
    revision: revision,
    updatedAt: updatedAt,
    changeId: _randomChangeId(random),
  );
}

final _entryGenerator = any.simple<JournalEntry>(
  generate: _randomEntry,
  shrink: (entry) sync* {
    if (entry.revision > 1) {
      yield entry.copyWith(revision: entry.revision - 1);
    }
    yield entry.copyWith(
      updatedAt: entry.updatedAt.subtract(const Duration(milliseconds: 1)),
    );
  },
);

final _entryPairGenerator = any.combine2(
  _entryGenerator,
  _entryGenerator,
  (JournalEntry a, JournalEntry b) => (a, b),
);

final _entryTripleGenerator = any.combine3(
  _entryGenerator,
  _entryGenerator,
  _entryGenerator,
  (JournalEntry a, JournalEntry b, JournalEntry c) => (a, b, c),
);

void main() {
  group('JournalSyncCompare ordering invariants (glados)', () {
    Glados<JournalEntry>(_entryGenerator).test(
      'reflexivity: compare(a, a) == 0',
      (entry) {
        expect(JournalSyncCompare.compare(entry, entry), 0);
        expect(JournalSyncCompare.winner(entry, entry), same(entry));
      },
    );

    Glados<(JournalEntry, JournalEntry)>(_entryPairGenerator).test(
      'anti-symmetry: sign(compare(a,b)) == -sign(compare(b,a))',
      (pair) {
        final a = pair.$1;
        final b = pair.$2;
        final forward = JournalSyncCompare.compare(a, b);
        final backward = JournalSyncCompare.compare(b, a);
        if (forward == 0) {
          expect(backward, 0);
        } else if (forward > 0) {
          expect(backward, lessThan(0));
        } else {
          expect(backward, greaterThan(0));
        }
      },
    );

    Glados<(JournalEntry, JournalEntry, JournalEntry)>(_entryTripleGenerator).test(
      'transitivity: compare(a,b)>0 && compare(b,c)>0 implies compare(a,c)>0',
      (triple) {
        final a = triple.$1;
        final b = triple.$2;
        final c = triple.$3;
        final ab = JournalSyncCompare.compare(a, b);
        final bc = JournalSyncCompare.compare(b, c);
        if (ab > 0 && bc > 0) {
          expect(JournalSyncCompare.compare(a, c), greaterThan(0));
        }
        if (ab < 0 && bc < 0) {
          expect(JournalSyncCompare.compare(a, c), lessThan(0));
        }
      },
    );

    Glados<(JournalEntry, JournalEntry)>(
      any.simple(
        generate: (random, size) {
          final low = random.nextInt(size.clamp(1, 20)) + 1;
          final high = low + random.nextInt(5) + 1;
          return (
            _entryWith(
              revision: low,
              updatedAt: DateTime.utc(2026, 2),
              changeId: 'aaa',
            ),
            _entryWith(
              revision: high,
              updatedAt: DateTime.utc(2026),
              changeId: 'zzz',
            ),
          );
        },
        shrink: (pair) sync* {
          yield (
            pair.$1.copyWith(revision: pair.$1.revision - 1),
            pair.$2,
          );
        },
      ),
    ).test(
      '3-tier: higher revision always wins regardless of updatedAt/changeId',
      (pair) {
        final lowRevision = pair.$1;
        final highRevision = pair.$2;
        if (highRevision.revision <= lowRevision.revision) return;

        expect(
          JournalSyncCompare.compare(highRevision, lowRevision),
          greaterThan(0),
        );
        expect(
          JournalSyncCompare.winner(lowRevision, highRevision),
          same(highRevision),
        );
      },
    );

    Glados<(JournalEntry, JournalEntry)>(
      any.simple(
        generate: (random, size) {
          final revision = random.nextInt(size.clamp(1, 20)) + 1;
          final baseMillis = random.nextInt(100_000);
          final earlier = DateTime.utc(2026).add(Duration(milliseconds: baseMillis));
          final later = earlier.add(const Duration(milliseconds: 1));
          return (
            _entryWith(
              revision: revision,
              updatedAt: earlier,
              changeId: _randomChangeId(random),
            ),
            _entryWith(
              revision: revision,
              updatedAt: later,
              changeId: _randomChangeId(random),
            ),
          );
        },
        shrink: (pair) sync* {
          yield (
            pair.$1,
            pair.$2.copyWith(
              updatedAt: pair.$2.updatedAt.subtract(const Duration(milliseconds: 1)),
            ),
          );
        },
      ),
    ).test(
      'equal revision: later updatedAt wins',
      (pair) {
        final earlier = pair.$1;
        final later = pair.$2;
        if (earlier.revision != later.revision) return;
        if (!earlier.updatedAt.isBefore(later.updatedAt)) return;

        expect(JournalSyncCompare.compare(later, earlier), greaterThan(0));
        expect(JournalSyncCompare.winner(earlier, later), same(later));
      },
    );

    Glados<(JournalEntry, JournalEntry)>(
      any.simple(
        generate: (random, size) {
          final revision = random.nextInt(size.clamp(1, 20)) + 1;
          final updatedAt = DateTime.utc(2026, 8, 18, 12, 0, 0, 123);
          final idA = 'a${random.nextInt(9999).toString().padLeft(4, '0')}';
          final idB = 'z${random.nextInt(9999).toString().padLeft(4, '0')}';
          return (
            _entryWith(revision: revision, updatedAt: updatedAt, changeId: idA),
            _entryWith(revision: revision, updatedAt: updatedAt, changeId: idB),
          );
        },
        shrink: (pair) sync* {
          yield (
            pair.$1.copyWith(changeId: 'a'),
            pair.$2.copyWith(changeId: 'z'),
          );
        },
      ),
    ).test(
      'millisecond timestamp collision: changeId tie-break is deterministic',
      (pair) {
        final a = pair.$1;
        final b = pair.$2;
        if (a.revision != b.revision) return;
        if (a.updatedAt != b.updatedAt) return;
        if (a.changeId == b.changeId) return;

        final cmp = JournalSyncCompare.compare(a, b);
        if (a.changeId.compareTo(b.changeId) > 0) {
          expect(cmp, greaterThan(0));
          expect(JournalSyncCompare.winner(a, b), same(a));
        } else {
          expect(cmp, lessThan(0));
          expect(JournalSyncCompare.winner(a, b), same(b));
        }
      },
    );
  });
}

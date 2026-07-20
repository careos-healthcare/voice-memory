import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_adaptive_timing_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const _reflection = Reflection(
  mood: 'thoughtful',
  emotionalIntensity: 2,
  recurringThemes: ['work'],
  exactLanguagePattern: '',
  concreteObservation: 'Work pressure showed up again today.',
  repeatedSignal: '',
);

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: 'I said yes again even though I had no capacity.',
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: _reflection,
    );

void main() {
  const engine = CuriosityAdaptiveTimingEngine();

  group('CuriosityAdaptiveTimingEngine', () {
    test('returns twenty-four hours when history has fewer than three entries', () {
      final currentEntryTime = DateTime(2026, 6, 12, 15, 30);
      final history = [
        _entry(id: 'e1', createdAt: DateTime(2026, 6, 10, 8)),
        _entry(id: 'e2', createdAt: DateTime(2026, 6, 11, 9)),
      ];

      final delay = engine.calculateOptimalDelay(
        history: history,
        currentEntryTime: currentEntryTime,
      );

      expect(delay, CuriosityAdaptiveTimingEngine.fallbackDelay);
    });

    test('targets next calendar day at the average hour from recent entries', () {
      final currentEntryTime = DateTime(2026, 6, 12, 15, 30);
      final history = [
        _entry(id: 'e1', createdAt: DateTime(2026, 6, 8, 8)),
        _entry(id: 'e2', createdAt: DateTime(2026, 6, 9, 9)),
        _entry(id: 'e3', createdAt: DateTime(2026, 6, 10, 10)),
        _entry(id: 'e4', createdAt: DateTime(2026, 6, 11, 11)),
        _entry(id: 'e5', createdAt: DateTime(2026, 6, 12, 12)),
      ];

      final delay = engine.calculateOptimalDelay(
        history: history,
        currentEntryTime: currentEntryTime,
      );

      final target = currentEntryTime.add(delay);
      expect(target.year, 2026);
      expect(target.month, 6);
      expect(target.day, 13);
      expect(target.hour, 10);
      expect(target.minute, 0);
      expect(delay, const Duration(hours: 18, minutes: 30));
    });

    test('uses only the last five entries when history is longer', () {
      final currentEntryTime = DateTime(2026, 6, 12, 20, 0);
      final history = [
        _entry(id: 'old', createdAt: DateTime(2026, 6, 5, 6)),
        _entry(id: 'e1', createdAt: DateTime(2026, 6, 8, 14)),
        _entry(id: 'e2', createdAt: DateTime(2026, 6, 9, 15)),
        _entry(id: 'e3', createdAt: DateTime(2026, 6, 10, 16)),
        _entry(id: 'e4', createdAt: DateTime(2026, 6, 11, 17)),
        _entry(id: 'e5', createdAt: DateTime(2026, 6, 12, 18)),
      ];

      final delay = engine.calculateOptimalDelay(
        history: history,
        currentEntryTime: currentEntryTime,
      );

      final target = currentEntryTime.add(delay);
      expect(target.day, 13);
      expect(target.hour, 16);
      expect(target.minute, 0);
      expect(delay, const Duration(hours: 20));
    });

    test('supports fractional average hours with minute rounding', () {
      final currentEntryTime = DateTime(2026, 6, 12, 9, 0);
      final history = [
        _entry(id: 'e1', createdAt: DateTime(2026, 6, 10, 8, 0)),
        _entry(id: 'e2', createdAt: DateTime(2026, 6, 11, 8, 30)),
        _entry(id: 'e3', createdAt: DateTime(2026, 6, 12, 9, 0)),
      ];

      final delay = engine.calculateOptimalDelay(
        history: history,
        currentEntryTime: currentEntryTime,
      );

      final target = currentEntryTime.add(delay);
      expect(target.day, 13);
      expect(target.hour, 8);
      expect(target.minute, 30);
      expect(delay, const Duration(hours: 23, minutes: 30));
    });
  });
}

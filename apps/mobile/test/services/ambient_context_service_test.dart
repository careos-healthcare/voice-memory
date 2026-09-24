import 'package:archiveme_mobile/models/ambient_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/ambient_context_service.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  );

  JournalEntry entry() {
    return JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 9, 22, 12),
      transcript: 'A quiet afternoon.',
      durationSeconds: 0,
      reflection: reflection,
    );
  }

  test('pill text and payload json keep the gathered fields', () async {
    final service = AmbientContextService(
      places: _PlaceReader(),
      weather: _WeatherReader(),
      steps: _StepReader(4200),
      calendar: _CalendarReader('Design review'),
      clock: () => DateTime.utc(2026, 9, 22, 18),
    );

    final saved = await service.attach(entry());
    final ambient = saved.display.ambientContext!;

    expect(
      ambient.pillText,
      '📍 London • ⛅ 18°C • 🚶 4,200 steps • 📅 Design review',
    );
    expect(saved.toResidualJson()['ambientContext'], ambient.toJson());

    final restored = JournalEntry.fromJson(saved.toJson());
    expect(restored.display.ambientContext, ambient);
  });

  test(
    'a denied permission and a slow probe finish as empty context',
    () async {
      final service = AmbientContextService(
        places: _SlowPlaceReader(),
        steps: _ThrowingStepReader(),
        calendar: _CalendarReader(null),
        budget: const Duration(milliseconds: 500),
      );

      final started = DateTime.now();
      final captured = await service.capture();
      final elapsed = DateTime.now().difference(started);

      expect(captured.isEmpty, isTrue);
      expect(elapsed.inMilliseconds, lessThan(800));
      final saved = await service.attach(entry());
      expect(saved.toResidualJson().containsKey('ambientContext'), isFalse);
    },
  );

  testWidgets('entry card fades in the ambient line on a phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ambient = const AmbientContext(
      locality: 'London',
      weatherLabel: '18°C',
      stepCount: 4200,
    );
    final shown = entry().copyWith(
      display: entry().display.copyWith(ambientContext: ambient),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveEntryCard(entry: shown, onTap: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ambient_context_pills')), findsOneWidget);
    expect(
      find.text('📍 London • ⛅ 18°C • 🚶 4,200 steps'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _PlaceReader extends AmbientPlaceReader {
  @override
  Future<AmbientPlace?> read() async {
    return const AmbientPlace(
      locality: 'London',
      latitude: 51.5,
      longitude: -0.12,
    );
  }
}

class _SlowPlaceReader extends AmbientPlaceReader {
  @override
  Future<AmbientPlace?> read() {
    return Future<AmbientPlace?>.delayed(
      const Duration(seconds: 3),
      () => const AmbientPlace(locality: 'Late'),
    );
  }
}

class _WeatherReader extends AmbientWeatherReader {
  @override
  Future<WeatherSnapshot?> read({
    required double latitude,
    required double longitude,
  }) async {
    return const WeatherSnapshot(label: '18°C', glyph: '⛅');
  }
}

class _StepReader extends AmbientStepReader {
  _StepReader(this.steps);

  final int steps;

  @override
  Future<int?> read() async => steps;
}

class _ThrowingStepReader extends AmbientStepReader {
  @override
  Future<int?> read() async => throw StateError('permission denied');
}

class _CalendarReader extends AmbientCalendarReader {
  _CalendarReader(this.title);

  final String? title;

  @override
  Future<String?> read() async => title;
}

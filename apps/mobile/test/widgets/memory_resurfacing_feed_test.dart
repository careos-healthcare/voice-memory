import 'dart:async';

import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing/memory_audio_wavebar.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing/memory_photo_masonry.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements WavebarTransport {
  _FakeTransport() : _positions = StreamController<Duration>.broadcast();

  final StreamController<Duration> _positions;
  Duration _position = Duration.zero;
  Duration? lastSeek;
  var playing = false;
  var playCalls = 0;

  @override
  Duration get position => _position;

  @override
  Duration get duration => const Duration(seconds: 40);

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _position = position;
    _positions.add(position);
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    await _positions.close();
  }
}

JournalEntry _entry({String? audioPath}) {
  return JournalEntry(
    id: 'memory-1',
    createdAt: DateTime(2025, 5, 19, 10),
    transcript: 'I want to spend more time traveling abroad',
    durationSeconds: 40,
    localAudioPath: audioPath,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: 'time traveling abroad',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

MemoryResurfacingCardData _card({
  String? audioPath,
  List<String> imageUrls = const [],
  MemoryPlace? place,
}) {
  return MemoryResurfacingCardData(
    entry: _entry(audioPath: audioPath),
    headline: 'You said this 1 year ago.',
    quoteSnippet: 'time traveling abroad',
    originalDateLabel: 'May 19, 2025',
    beliefRelation: '',
    imageUrls: imageUrls,
    place: place,
  );
}

void main() {
  test('photo columns follow the card width', () {
    expect(memoryPhotoColumnCount(390), 2);
    expect(memoryPhotoColumnCount(600), 3);
    expect(memoryPhotoColumnCount(1032), 3);
  });

  testWidgets('feed scrolls as slivers and hides empty media', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: OnThisDaySection(
            cards: [_card()],
            onCardTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byKey(const Key('memory_photo_grid_2')), findsNothing);
    expect(find.byKey(const Key('memory_audio_wavebar')), findsNothing);
    expect(find.byKey(const Key('memory_location_map')), findsNothing);
    expect(find.text('You said this 1 year ago.'), findsOneWidget);
  });

  testWidgets('photos, voice scrub, and place render on a wide card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transport = _FakeTransport();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: MemoryResurfacingSection(
            cards: [
              _card(
                audioPath: '/tmp/voice-note.m4a',
                imageUrls: const [
                  'https://example.test/a.jpg',
                  'https://example.test/b.jpg',
                  'https://example.test/c.jpg',
                ],
                place: const MemoryPlace(
                  latitude: 51.5,
                  longitude: -0.12,
                  label: 'South bank',
                ),
              ),
            ],
            onCardTap: (_) => opened += 1,
            transportFactory: (_) => transport,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('memory_photo_grid_3')), findsOneWidget);
    expect(find.byKey(const Key('memory_location_map')), findsOneWidget);
    expect(find.text('South bank'), findsOneWidget);

    await tester.tap(find.byKey(const Key('memory_audio_scrub')));
    await tester.pump();
    expect(transport.lastSeek, isNotNull);
    expect(transport.lastSeek!.inSeconds, inInclusiveRange(15, 25));
    expect(opened, 0);

    await tester.tap(find.byKey(const Key('memory_audio_play')));
    await tester.pump();
    expect(transport.playCalls, 1);
    expect(opened, 0);

    await tester.tap(find.text('You said this 1 year ago.'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('a phone-width card uses two photo columns', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: OnThisDaySection(
            cards: [
              _card(
                imageUrls: const [
                  'https://example.test/a.jpg',
                  'https://example.test/b.jpg',
                ],
              ),
            ],
            onCardTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('memory_photo_grid_2')), findsOneWidget);
  });
}

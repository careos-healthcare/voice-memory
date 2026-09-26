import 'package:archiveme_mobile/audio/audio_player_service.dart';
import 'package:archiveme_mobile/features/archive/controllers/on_this_day_controller.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  String transcript = 'the river was high',
  String? audio,
  List<String> images = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 8,
    localAudioPath: audio,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    imageEvidence: images.isEmpty
        ? null
        : ImageEvidence(
            evidenceId: id,
            caption: '',
            mimeType: 'image/jpeg',
            attachedAt: at,
            images: images,
          ),
  );
}

void main() {
  test('past years are labeled and ordered with the closest year first', () {
    final today = DateTime(2026, 9, 26);
    final groups = OnThisDayController.group(
      today: today,
      silencedIds: {'hidden'},
      entries: [
        _entry(id: 'two', at: DateTime(2024, 9, 26)),
        _entry(id: 'one', at: DateTime(2025, 9, 26)),
        _entry(id: 'today', at: DateTime(2026, 9, 26)),
        _entry(id: 'other', at: DateTime(2024, 1, 2)),
        _entry(id: 'hidden', at: DateTime(2023, 9, 26)),
      ],
    );

    expect(groups.keys.toList(), ['1 year ago', '2 years ago']);
    expect(groups['1 year ago']!.single.id, 'one');
    expect(groups['2 years ago']!.single.id, 'two');
  });

  testWidgets('an empty day explains that a recording shows up next year', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OnThisDayView(
            now: DateTime(2026, 9, 26),
            entries: [_entry(id: 'today', at: DateTime(2026, 9, 26))],
          ),
        ),
      ),
    );

    expect(find.text(OnThisDayController.emptyCopy), findsOneWidget);
  });

  testWidgets('a photo sits above the words and hiding removes the card', (
    tester,
  ) async {
    String? silenced;
    String? played;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OnThisDayView(
            now: DateTime(2026, 9, 26),
            onSilence: (id) async => silenced = id,
            audioPlayer: AudioPlayerService(
              playFile: (url) async => played = url,
            ),
            entries: [
              _entry(
                id: 'then',
                at: DateTime(2025, 9, 26),
                audio: '/tmp/then.m4a',
                images: const ['/tmp/then.jpg'],
              ),
            ],
          ),
        ),
      ),
    );

    final photo = tester.getTopLeft(
      find.byKey(const Key('archive_entry_images_then')),
    );
    final words = tester.getTopLeft(find.text('the river was high'));
    expect(photo.dy, lessThan(words.dy));

    await tester.tap(find.byKey(const Key('on_this_day_play_then')));
    await tester.pump();
    expect(played, '/tmp/then.m4a');

    await tester.tap(find.byKey(const Key('on_this_day_menu_then')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't show me this again"));
    await tester.pumpAndSettle();
    expect(
      find.text('Hide this memory? It will no longer appear in On This Day.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('on_this_day_hide_confirm')));
    await tester.pumpAndSettle();

    expect(silenced, 'then');
    expect(find.byKey(const Key('on_this_day_then')), findsNothing);
    expect(find.text(OnThisDayController.emptyCopy), findsOneWidget);
  });
}

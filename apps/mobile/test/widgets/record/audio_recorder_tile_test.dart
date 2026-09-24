import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:archiveme_mobile/widgets/record/audio_recorder_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between Passive Note and Interactive Reflection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dualModeAudioPortsProvider.overrideWithValue(
            DualModeAudioPorts(
              isSpeech: (_) => false,
              transcribe: (_) async => '',
              reply: (_) async => '',
              play: (_) async {},
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AudioRecorderTile())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio_recorder_tile')), findsOneWidget);
    expect(find.text('Passive Note'), findsOneWidget);
    expect(find.text('Interactive Reflection'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('audio_recorder_mode_passive')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('audio_recorder_mode_interactive')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('audio_recorder_mode_interactive')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('audio_recorder_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('audio_recorder_mode_passive')));
    await tester.pumpAndSettle();
    expect(find.text('Record'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('audio_recorder_mode_passive')),
          )
          .selected,
      isTrue,
    );
  });
}

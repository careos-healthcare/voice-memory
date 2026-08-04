import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_voice_playback_player.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/widgets/live_voice_interactive_player_card.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/live_voice/live_voice_status_card.dart';

void main() {
  const pitchContour = [120.0, 140.0, 130.0, 150.0, 125.0];

  group('LiveVoiceInteractivePlayerCard', () {
    testWidgets('renders pitch overlay and transport controls', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceInteractivePlayerCard(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_interactive_player_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pitch_contour_overlay')), findsOneWidget);
      expect(
        find.byKey(const Key('live_voice_playback_toggle')),
        findsOneWidget,
      );
      expect(find.text('00:00 / 00:10'), findsOneWidget);
    });

    testWidgets('hides when playback session is not loaded', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceInteractivePlayerCard(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_interactive_player_empty')),
        findsOneWidget,
      );
    });

    testWidgets('play toggle starts and pauses playback', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 5));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceInteractivePlayerCard(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      expect(player.isPlaying, isFalse);

      await tester.tap(find.byKey(const Key('live_voice_playback_toggle')));
      await tester.pump();

      expect(player.isPlaying, isTrue);

      await tester.tap(find.byKey(const Key('live_voice_playback_toggle')));
      await tester.pump();

      expect(player.isPlaying, isFalse);
    });

    testWidgets('scrubs playback from pitch overlay tap', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceInteractivePlayerCard(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('pitch_contour_overlay'))),
      );
      await tester.pump();

      expect(player.position, greaterThan(Duration.zero));
    });

    testWidgets('skip buttons move playback position', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 30));
      player.seek(const Duration(seconds: 15));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceInteractivePlayerCard(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('live_voice_playback_rewind')));
      await tester.pump();

      expect(player.position, const Duration(seconds: 5));

      await tester.tap(find.byKey(const Key('live_voice_playback_forward')));
      await tester.pump();

      expect(player.position, const Duration(seconds: 15));
    });
  });

  group('LiveVoiceStatusCard interactive player', () {
    testWidgets('shows unified player while model is speaking', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 8));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoiceStatusCard(
              visualState: LiveVoiceVisualState.speaking,
              seconds: 12,
              playbackQueueDepth: 2,
              playbackPlayer: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_interactive_player_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pitch_contour_overlay')), findsOneWidget);
      expect(find.text('00:00 / 00:08'), findsOneWidget);
    });
  });
}

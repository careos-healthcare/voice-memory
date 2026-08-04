import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_voice_playback_player.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/widgets/live_voice_playback_pitch_overlay.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/widgets/pitch_contour_overlay_widget.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/live_voice/live_voice_status_card.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';

void main() {
  const pitchContour = [120.0, 140.0, 130.0, 150.0, 125.0];

  group('PitchContourOverlayWidget', () {
    testWidgets('renders custom paint and seeks on tap', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 10));
      var seekTarget = Duration.zero;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PitchContourOverlayWidget(
              pitchContour: pitchContour,
              currentPosition: const Duration(seconds: 2),
              totalDuration: const Duration(seconds: 10),
              onSeek: (position) => seekTarget = position,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pitch_contour_overlay')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('pitch_contour_overlay')),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('pitch_contour_overlay'))),
      );
      await tester.pump();

      expect(seekTarget.inMilliseconds, greaterThan(0));
    });

    testWidgets('connected overlay binds player seek', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);
      player.loadSession(totalDuration: const Duration(seconds: 5));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LiveVoicePlaybackPitchOverlay(
              player: player,
              pitchContour: pitchContour,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('live_voice_pitch_overlay')), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('pitch_contour_overlay'))),
      );
      await tester.pump();

      expect(player.position, greaterThan(Duration.zero));
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
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_voice_playback_player.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/live_voice_session_presentation.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/live_voice/live_voice_playback_progress_bar.dart';
import 'package:voicememory_mobile/widgets/live_voice/live_voice_status_card.dart';

void main() {
  group('LiveVoicePlaybackProgressBar', () {
    testWidgets('renders synchronized playback position', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      player.loadSession(totalDuration: const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LiveVoicePlaybackProgressBar(player: player)),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_playback_progress')),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('00:10'), findsOneWidget);
    });

    testWidgets('hides when no playback session is loaded', (tester) async {
      final player = LiveVoicePlaybackPlayer();
      addTearDown(player.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LiveVoicePlaybackProgressBar(player: player)),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_playback_progress_empty')),
        findsOneWidget,
      );
    });
  });

  group('LiveVoiceStatusCard', () {
    testWidgets('shows playback progress while model is speaking', (
      tester,
    ) async {
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
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('live_voice_interactive_player_card')),
        findsOneWidget,
      );
      expect(find.text('00:00 / 00:08'), findsOneWidget);
    });
  });
}

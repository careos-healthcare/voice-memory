import 'package:archiveme_mobile/audio/audio_player_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a matched chunk seeks by milliseconds', () async {
    Duration? sought;
    final player = AudioPlayerService(
      playFile: (_) async {},
      seekTo: (position) async {
        sought = position;
      },
    );

    await player.play('clip.m4a');
    await player.seek(const Duration(milliseconds: 1500));

    expect(sought, const Duration(milliseconds: 1500));
  });
}

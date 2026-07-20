import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:voicememory_mobile/features/live_audio/domain/services/live_audio_transcript_collector.dart';

void main() {
  test('prefers input transcription over output transcription', () {
    final collector = LiveAudioTranscriptCollector();
    collector.ingest(const LiveInputTranscriptionEvent(text: 'I felt stuck'));
    collector.ingest(const LiveOutputTranscriptionEvent(text: 'Model reply'));
    expect(collector.bestTranscript, 'I felt stuck');
  });

  test('falls back to output transcription when input is empty', () {
    final collector = LiveAudioTranscriptCollector();
    collector.ingest(const LiveOutputTranscriptionEvent(text: 'Fallback text'));
    expect(collector.bestTranscript, 'Fallback text');
  });
}

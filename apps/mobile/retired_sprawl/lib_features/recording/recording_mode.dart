import 'package:archiveme_mobile/features/live_audio/presentation/live_voice_session_copy.dart';

/// How Record captures a moment — passive mic capture vs live AI conversation.
enum RecordingMode {
  /// Standard record → transcribe → analyze pipeline.
  passiveJournaling,

  /// Real-time WebSocket session with bidirectional AI prompting.
  conversationalJournaling,
}

extension RecordingModeLabels on RecordingMode {
  String get toggleLabel => switch (this) {
    RecordingMode.passiveJournaling =>
      LiveVoiceSessionCopy.reflectiveModeLabel,
    RecordingMode.conversationalJournaling =>
      LiveVoiceSessionCopy.liveConversationLabel,
  };

  String get recordCtaLabel => switch (this) {
    RecordingMode.passiveJournaling => 'Record',
    RecordingMode.conversationalJournaling =>
      LiveVoiceSessionCopy.recordEntryCta,
  };

  bool get usesLiveConversation =>
      this == RecordingMode.conversationalJournaling;
}
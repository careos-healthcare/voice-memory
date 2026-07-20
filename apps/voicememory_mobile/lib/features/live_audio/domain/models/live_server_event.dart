sealed class LiveServerEvent {
  const LiveServerEvent();
}

class LiveSetupCompleteEvent extends LiveServerEvent {
  const LiveSetupCompleteEvent();
}

class LiveAudioOutputEvent extends LiveServerEvent {
  const LiveAudioOutputEvent({
    required this.pcmBytes,
    this.mimeType,
  });

  final List<int> pcmBytes;
  final String? mimeType;
}

class LiveInputTranscriptionEvent extends LiveServerEvent {
  const LiveInputTranscriptionEvent({required this.text});
  final String text;
}

class LiveOutputTranscriptionEvent extends LiveServerEvent {
  const LiveOutputTranscriptionEvent({required this.text});
  final String text;
}

class LiveInterruptedEvent extends LiveServerEvent {
  const LiveInterruptedEvent();
}

class LiveTurnCompleteEvent extends LiveServerEvent {
  const LiveTurnCompleteEvent();
}

class LiveGoAwayEvent extends LiveServerEvent {
  const LiveGoAwayEvent({this.timeLeft});
  final String? timeLeft;
}

class LiveServerErrorEvent extends LiveServerEvent {
  const LiveServerErrorEvent({required this.message});
  final String message;
}

class LiveSocketClosedEvent extends LiveServerEvent {
  const LiveSocketClosedEvent({this.reason});
  final String? reason;
}

class LiveUnknownServerEvent extends LiveServerEvent {
  const LiveUnknownServerEvent({required this.topLevelKeys});
  final List<String> topLevelKeys;
}

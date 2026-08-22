/// Transcription / save pipeline phase for Record.
class CaptureProcessingController {
  bool processing = false;
  String? stageLabel;
  String? syncNote;
  String? error;

  bool get isActive => processing;

  void begin({String? stage}) {
    processing = true;
    stageLabel = stage;
    error = null;
  }

  void end() {
    processing = false;
    stageLabel = null;
    syncNote = null;
  }

  void reset() {
    processing = false;
    stageLabel = null;
    syncNote = null;
    error = null;
  }
}
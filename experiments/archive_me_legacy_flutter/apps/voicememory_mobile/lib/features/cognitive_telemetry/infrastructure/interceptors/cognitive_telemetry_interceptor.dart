import '../../../../models/journal_entry.dart';
import '../../../journal/domain/interceptors/journal_save_interceptor.dart';
import '../../application/cognitive_analyzer.dart';
import '../../application/live_voice_acoustic_session_bridge.dart';
import '../../domain/cognitive_metrics.dart';

typedef CognitiveMetricsAnalyzedHandler =
    void Function(CognitiveMetrics metrics);

/// Runs acoustic cognitive analysis after live-voice vault commit + journal save.
class CognitiveTelemetryInterceptor implements JournalSaveInterceptor {
  CognitiveTelemetryInterceptor({
    LiveVoiceAcousticSessionBridge? sessionBridge,
    CognitiveAnalyzer? analyzer,
    this._onMetricsAnalyzed,
  }) : _sessionBridge = sessionBridge ?? LiveVoiceAcousticSessionBridge(),
       _analyzer = analyzer ?? CognitiveAnalyzer();

  static const liveVoiceCaptureTag = 'live_voice_capture';
  static const liveVoiceVaultRecoveryTag = 'live_voice_vault_recovery';

  final LiveVoiceAcousticSessionBridge _sessionBridge;
  final CognitiveAnalyzer _analyzer;
  final CognitiveMetricsAnalyzedHandler? _onMetricsAnalyzed;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    if (!_isLiveVoiceEntry(entry)) return;

    final session = _sessionBridge.consumePending();
    if (session == null) return;

    final metrics = await _analyzer.analyzeSession(
      sessionId: session.sessionId,
      transcript: entry.transcript,
      pitchContour: session.pitchContour,
    );
    _onMetricsAnalyzed?.call(metrics);
  }

  static bool _isLiveVoiceEntry(JournalEntry entry) {
    final tag = entry.captureContextTag;
    return tag == liveVoiceCaptureTag || tag == liveVoiceVaultRecoveryTag;
  }
}

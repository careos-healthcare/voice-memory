import '../../live_audio_constants.dart';
import '../services/live_proxy_url.dart';

/// Backend-minted proxy session — never contains a Gemini API key.
class LiveAudioSessionConfig {
  const LiveAudioSessionConfig({
    required this.sessionId,
    required this.sessionToken,
    required this.proxyWebSocketUrl,
    required this.expiresAt,
    required this.model,
    required this.inputAudioMimeType,
    required this.outputAudioMimeType,
    this.vaultRecoverySecret,
  });

  factory LiveAudioSessionConfig.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expiresAt'];
    return LiveAudioSessionConfig(
      sessionId: json['sessionId'] as String,
      sessionToken: json['sessionToken'] as String,
      proxyWebSocketUrl: normalizeProxyWebSocketUrl(
        json['proxyWebSocketUrl'] as String,
      ),
      expiresAt: expiresAtRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtRaw)
          : DateTime.parse(expiresAtRaw as String),
      model: json['model'] as String,
      inputAudioMimeType:
          json['inputAudioMimeType'] as String? ?? liveInputAudioMime,
      outputAudioMimeType:
          json['outputAudioMimeType'] as String? ?? liveOutputAudioMime,
      vaultRecoverySecret: json['vaultRecoverySecret'] as String?,
    );
  }

  final String sessionId;
  final String sessionToken;
  final String proxyWebSocketUrl;
  final DateTime expiresAt;
  final String model;
  final String inputAudioMimeType;
  final String outputAudioMimeType;
  final String? vaultRecoverySecret;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

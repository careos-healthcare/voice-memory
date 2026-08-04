class RealtimeSessionConfig {
  const RealtimeSessionConfig({
    required this.sessionId,
    required this.clientSecret,
    required this.expiresAt,
    required this.model,
    required this.voice,
    required this.sampleRateHz,
    required this.realtimeWebSocketUrl,
  });

  final String sessionId;
  final String clientSecret;
  final DateTime expiresAt;
  final String model;
  final String voice;
  final int sampleRateHz;
  final Uri realtimeWebSocketUrl;

  factory RealtimeSessionConfig.fromJson(Map<String, dynamic> json) {
    final secret = json['clientSecret'] as String? ?? '';
    final url = Uri.tryParse(json['realtimeWebSocketUrl'] as String? ?? '');
    if (secret.isEmpty || url == null || url.scheme != 'wss') {
      throw const FormatException('Invalid realtime session response.');
    }
    return RealtimeSessionConfig(
      sessionId: json['sessionId'] as String? ?? '',
      clientSecret: secret,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['expiresAt'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      model: json['model'] as String? ?? '',
      voice: json['voice'] as String? ?? '',
      sampleRateHz: (json['sampleRateHz'] as num?)?.toInt() ?? 24000,
      realtimeWebSocketUrl: url,
    );
  }
}

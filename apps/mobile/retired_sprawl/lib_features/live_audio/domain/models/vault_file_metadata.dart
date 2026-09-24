/// Metadata extracted from an encrypted on-disk live-audio vault file.
class VaultFileMetadata {
  const VaultFileMetadata({
    required this.sessionId,
    required this.frameCount,
    required this.durationSeconds,
    this.recoverySecretKeyBytes,
    this.serverRecoverable = true,
  });

  final String sessionId;
  final int frameCount;
  final int durationSeconds;
  final List<int>? recoverySecretKeyBytes;
  final bool serverRecoverable;
}

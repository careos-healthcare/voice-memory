abstract final class LlamaModelDownloadCopy {
  static const title = 'On-device AI model';
  static const description =
      'Optional download of about 1 GB. It runs locally, downloads on Wi-Fi '
      'only, and can be removed at any time.';
  static const attribution =
      'Qwen2.5 by Alibaba Cloud (Qwen Team) · Apache-2.0';

  static const notConfigured = 'On-device AI is not available in this version.';
  static const optInRequired = 'Not installed. Download when you are ready.';
  static const checkingStorage = 'Checking available storage…';
  static const waitingForWifi = 'Waiting for Wi-Fi to continue.';
  static const userPaused = 'Download paused.';
  static const verifying = 'Verifying the downloaded model…';
  static const ready = 'Ready for private, on-device AI.';
  static const failed = 'The model download could not be completed.';

  static String downloading(int percent) => 'Downloading · $percent%';
}

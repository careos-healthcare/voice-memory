/// Normalizes compile-time share payloads before copy/share actions.
abstract class ArchiveShareText {
  ArchiveShareText._();

  static const String archiveMeMarker = 'ArchiveMe';

  static const List<String> bannedConsumerMarkers = [
    'VoiceMemory',
    'ChatGPT',
    'OpenAI',
  ];

  static bool isShareable(String? text) =>
      text != null && text.trim().isNotEmpty;

  static String normalize(String text) => text.trim();

  static bool includesArchiveMe(String text) => text.contains(archiveMeMarker);

  static bool includesBannedConsumerCopy(String text) {
    for (final marker in bannedConsumerMarkers) {
      if (text.contains(marker)) return true;
    }
    return false;
  }
}

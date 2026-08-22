/// Copy for image-evidence attachment UI.
abstract final class ImageEvidenceCopy {
  ImageEvidenceCopy._();

  static const panelTitle = 'Attach photo evidence';
  static const captionHint =
      'What does this photo show? This caption becomes citeable evidence.';
  static const galleryCta = 'Choose photo';
  static const cameraCta = 'Take photo';
  static const removeCta = 'Remove photo';

  static String attachedLabel({String? filename, int? byteLength}) {
    final name = filename?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Attached: $name';
    }
    if (byteLength != null && byteLength > 0) {
      final kb = (byteLength / 1024).round();
      return 'Attached image (~${kb}KB)';
    }
    return 'Photo attached';
  }
}
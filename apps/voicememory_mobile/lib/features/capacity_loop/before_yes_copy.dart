import '../../product/archive_positioning_copy.dart';

/// Copy for the before-you-say-yes pause flow — capacity-specific, no journal text.
abstract final class BeforeYesCopy {
  BeforeYesCopy._();

  static const recordRoute = '/record';

  static const title = ArchivePositioningCopy.beforeLabel;
  static const body =
      '${ArchivePositioningCopy.beforeBody} Your archive can help you see what keeps pulling you in.';
  static const pauseCta = 'Pause before yes';
  static const alreadyYesCta = ArchivePositioningCopy.afterLabel;
  static const recordPrompt =
      'What are you about to agree to, and what makes it hard to pause?';

  static const loopSectionTitle = 'Before next yes';
  static const loopSectionBody =
      'Next time you feel the pull to agree, save that moment first.';

  static String recordRouteWithPrompt(String prompt, {bool autostart = true}) {
    final encoded = Uri.encodeComponent(prompt);
    return '$recordRoute?prompt=$encoded${autostart ? '&autostart=1' : ''}';
  }
}

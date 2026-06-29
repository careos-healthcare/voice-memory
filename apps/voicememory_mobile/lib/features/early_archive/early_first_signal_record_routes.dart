import 'early_first_signal_copy.dart';

/// Record handoff for the confirmed-repeat return prompt.
abstract final class EarlyFirstSignalRecordRoutes {
  EarlyFirstSignalRecordRoutes._();

  static const recordRoute = '/record';

  static String routeWithTriggerPrompt({bool autostart = false}) {
    final encoded = Uri.encodeComponent(
      EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
    );
    return '$recordRoute?prompt=$encoded${autostart ? '&autostart=1' : ''}';
  }

  static String routeWithWhatHelpedPrompt({bool autostart = false}) {
    final encoded = Uri.encodeComponent(
      EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
    );
    return '$recordRoute?prompt=$encoded${autostart ? '&autostart=1' : ''}';
  }
}

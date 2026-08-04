import 'dart:io';

const recordingFeatureSourcePaths = <String>[
  'lib/screens/record_screen.dart',
  'lib/features/recording/recording_state_controller.dart',
  'lib/features/recording/recording_dependencies.dart',
];

String readRecordingFeatureSource() {
  return recordingFeatureSourcePaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}

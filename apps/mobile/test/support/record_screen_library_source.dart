import 'dart:io';

/// Relative paths (from `apps/mobile/`) for the [RecordScreen] library unit.
///
/// [recordScreenLibraryPaths.first] is the card-layout source file used by
/// repair-lab static tests that read a single file via [File].
const recordScreenLibraryPaths = [
  'lib/features/recording/views/record_pre_capture_cards.dart',
  'lib/features/recording/recording_screen.dart',
  'lib/features/recording/recording_build_context.dart',
  'lib/features/recording/record_build_context_adapter.dart',
  'lib/features/recording/record_surface_input_builder.dart',
  'lib/features/recording/recording_build_context_resolver.dart',
  'lib/features/recording/record_surface_resolver.dart',
  'lib/features/recording/recording_audio_listener.dart',
  'lib/features/recording/recording_state_handlers.dart',
  'lib/features/recording/recording_state_build_dispatch.dart',
  'lib/features/recording/widgets/recording_permission_panel.dart',
  'lib/features/recording/views/record_capture_state_section.dart',
  'lib/features/recording/views/record_post_save_cards.dart',
  'lib/features/recording/views/record_screen_body.dart',
  'lib/features/recording/views/record_screen_scaffold.dart',
  'lib/features/recording/widgets/recording_capture_actions_widget.dart',
  'lib/features/recording/widgets/recording_controls_widget.dart',
  'lib/features/recording/recording_state_controller.dart',
  'lib/features/recording/recording_audio_visualizer.dart',
  'lib/features/recording/recording_transcription_view.dart',
];

/// Concatenated Dart source for the record screen library — used by static
/// layout and surface-priority audit tests.
String readRecordScreenLibrarySource() {
  final buffer = StringBuffer();
  for (final path in recordScreenLibraryPaths) {
    buffer.writeln(File(path).readAsStringSync());
    buffer.writeln();
  }
  return buffer.toString();
}

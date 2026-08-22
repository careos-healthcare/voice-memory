import 'package:archiveme_mobile/features/evidence_method/record_entry_session_notifier.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'record_entry_session_state.dart';

final recordEntrySessionProvider =
    NotifierProvider<RecordEntrySessionNotifier, RecordEntrySessionState>(
      RecordEntrySessionNotifier.new,
    );

final recordEntrySessionNotifierProvider = Provider<RecordEntrySessionNotifier>(
  (ref) => ref.read(recordEntrySessionProvider.notifier),
);

final recordEntryShowsGlobalOverlayProvider = Provider<bool>((ref) {
  return ref.watch(recordEntrySessionProvider).showGlobalRecordingOverlay;
});
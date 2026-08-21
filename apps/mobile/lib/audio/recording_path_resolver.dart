import 'dart:io';

/// Resolves capture file paths for the unified `record` plugin recorder.
class RecordingPathResolver {
  String testRecordingPath() {
    return '${Directory.systemTemp.path}/vm_rec_test.m4a';
  }

  String productionRecordingPath(String directoryPath) {
    return '$directoryPath/vm_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  String retryRecordingPath(String directoryPath) {
    return '$directoryPath/vm_rec_retry_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }
}

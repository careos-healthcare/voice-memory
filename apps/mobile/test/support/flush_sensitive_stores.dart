import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';

/// Await in-flight encrypted-store writes before test sandbox teardown.
Future<void> flushSensitiveStoresForTest() async {
  await ArchiveInsightFeedbackStore.flushForTest();
  await PatternNameStore.flushForTest();
}

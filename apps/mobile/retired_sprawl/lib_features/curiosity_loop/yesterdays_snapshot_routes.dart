import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_copy.dart';

/// Record handoff for the curiosity loop snapshot screen.
abstract final class YesterdaysSnapshotRoutes {
  YesterdaysSnapshotRoutes._();

  static String recordHandoff({required String prompt, bool autostart = true}) {
    final encoded = Uri.encodeComponent(prompt);
    return '${YesterdaysSnapshotCopy.recordRoute}?prompt=$encoded'
        '${autostart ? '&autostart=1' : ''}';
  }
}
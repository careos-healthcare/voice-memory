import 'package:archiveme_mobile/features/capture_flow/capture_routine_launch_controller.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CaptureRoutineLaunchController.resetForTest);

  test('queues pending routine when navigation override declines', () {
    CaptureRoutineLaunchController.navigateOverrideForTest = (_) => false;

    CaptureRoutineLaunchController.handleNotificationPayload('routine:evening');

    expect(
      CaptureRoutineLaunchController.pendingRoutine,
      JournalRoutineKind.evening,
    );
    expect(
      CaptureRoutineLaunchController.takePendingRoutine(),
      JournalRoutineKind.evening,
    );
  });
}

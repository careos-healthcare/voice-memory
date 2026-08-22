import 'package:archiveme_mobile/services/app_services.dart';

/// Stops background workers and closes sqlite before test harness teardown.
Future<void> settleAppServicesForTest({
  Duration delay = const Duration(milliseconds: 450),
}) async {
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  await AppServices.shutdownForTest();
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

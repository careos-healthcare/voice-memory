import 'package:archiveme_mobile/billing/v1/app_services_paywall_dependencies.dart' show AppServicesPaywallDependencies;
import 'package:archiveme_mobile/core/di/v1_account_dependencies.dart' show V1AccountDependencies;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show AppServices;
import 'package:archiveme_mobile/services/app_services.dart' show AppServices;

/// V1 critical-path sources that must not access [AppServices.instance]
/// directly. Composition roots ([V1AccountDependencies.fromAppServices],
/// [AppServicesPaywallDependencies]) are exempt.
abstract final class V1CriticalPathFiles {
  V1CriticalPathFiles._();

  static const noServiceLocatorAccess = [
    'lib/features/capture_flow/capture_flow_controller.dart',
    'lib/features/capture_flow/ui/capture_screen.dart',
    'lib/features/capture_flow/ui/capture_screen_host.dart',
    'lib/services/capture_pipeline_service.dart',
    'lib/screens/delete_account_screen.dart',
    'lib/screens/archive_belief_screen.dart',
    'lib/screens/entry_detail_screen.dart',
  ];
}
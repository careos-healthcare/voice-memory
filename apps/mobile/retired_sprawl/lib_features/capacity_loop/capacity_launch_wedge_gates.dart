import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_gates.dart';

/// First-session visibility for capacity-yes wedge — no journal text.
abstract final class CapacityLaunchWedgeGates {
  CapacityLaunchWedgeGates._();

  static bool inEarlyActivationPhase({
    required bool capacityWedgeActive,
    required int capacityMomentCount,
  }) =>
      capacityWedgeActive &&
      capacityMomentCount < CapacityThreeMomentGates.activationTarget;

  static bool showAdvancedSurfaceOnArchiveHome({
    required bool capacityWedgeActive,
    required int capacityMomentCount,
  }) => !inEarlyActivationPhase(
    capacityWedgeActive: capacityWedgeActive,
    capacityMomentCount: capacityMomentCount,
  );
}
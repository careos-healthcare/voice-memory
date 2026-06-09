import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../loop_mode/loop_mode_model.dart';

/// Navigation for the prove_enough full evidence trail.
abstract final class ProveEnoughEvidenceTrailNavigation {
  ProveEnoughEvidenceTrailNavigation._();

  static const routePath = '/prove-enough/evidence-trail';

  static void open(BuildContext context) {
    context.push(routePath);
  }

  static bool shouldOpenForLoop(String? loopModeId) =>
      loopModeId == LoopModeIds.proveEnough;
}

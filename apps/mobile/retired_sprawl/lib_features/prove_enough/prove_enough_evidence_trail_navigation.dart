import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Navigation for the prove_enough full evidence trail.
abstract class ProveEnoughEvidenceTrailNavigation {
  ProveEnoughEvidenceTrailNavigation._();

  static const routePath = '/prove-enough/evidence-trail';

  static void open(BuildContext context) {
    unawaited(context.push(routePath));
  }

  static bool shouldOpenForLoop(String? loopModeId) =>
      loopModeId == LoopModeIds.proveEnough;
}
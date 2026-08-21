import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show RouteBase;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safe route location reads for widgets outside [RouteBase.builder] subtrees.
///
/// [GoRouterState.of] only works under a route builder. Shell widgets such as
/// [MaterialApp.router]'s `builder` must use [GoRouter.maybeOf] instead.
abstract class RouterLocation {
  RouterLocation._();

  /// Current path, or null when no [GoRouter] is available above [context].
  static String? currentPath(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return null;
    return router.routeInformationProvider.value.uri.path;
  }
}
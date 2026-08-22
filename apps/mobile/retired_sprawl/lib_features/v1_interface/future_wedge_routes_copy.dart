/// Future wedge acquisition routes — not V1 live scope.
abstract final class FutureWedgeRoutesCopy {
  FutureWedgeRoutesCopy._();

  static const headline = 'Future wedge routes (not V1 live)';

  static const note =
      'Prove-enough and capacity-yes are the only live wedge entry points in V1. '
      'Additional routes stay gated until first-proof and paid-intent evidence pass.';

  static const futureRoutes = <String>[
    '/start/work-pressure',
    '/start/rest-guilt',
    '/start/relationship-replay',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield note;
    yield* futureRoutes;
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation for the monthly ambition pressure review.
abstract final class MonthlyAmbitionPressureReviewNavigation {
  MonthlyAmbitionPressureReviewNavigation._();

  static const routePath = '/prove-enough/monthly-review';

  static void open(BuildContext context) {
    context.push(routePath);
  }
}

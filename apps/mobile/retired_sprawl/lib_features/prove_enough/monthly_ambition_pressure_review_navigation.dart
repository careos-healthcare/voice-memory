import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Navigation for the monthly ambition pressure review.
abstract class MonthlyAmbitionPressureReviewNavigation {
  MonthlyAmbitionPressureReviewNavigation._();

  static const routePath = '/prove-enough/monthly-review';

  static void open(BuildContext context) {
    unawaited(context.push(routePath));
  }
}
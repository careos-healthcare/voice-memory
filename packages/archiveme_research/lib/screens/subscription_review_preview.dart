import 'package:archiveme_mobile/billing/longer_story_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Static paywall for App Store subscription review screenshots.
///
/// Open via `/subscription-review-preview` (iPhone 15 Pro: 393×852 logical).
/// The purchase control is present because this screen is the after-proof view.
class SubscriptionReviewPreviewScreen extends StatelessWidget {
  const SubscriptionReviewPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: const Scaffold(
        body: LongerStoryPaywall(
          patternTitle: LongerStoryPaywall.reviewPattern,
          quotes: LongerStoryPaywall.reviewQuotes,
          purchaseAllowed: true,
        ),
      ),
    );
  }
}

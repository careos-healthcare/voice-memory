import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:url_launcher/url_launcher.dart';

import 'testflight_feedback_copy.dart';

/// Opens the TestFlight feedback mail draft in the user's email app.
abstract final class TestFlightFeedbackLauncher {
  TestFlightFeedbackLauncher._();

  @visibleForTesting
  static Future<bool> Function(Uri uri)? launchUrlForTest;

  static Uri mailtoUri({
    String to = TestFlightFeedbackCopy.emailTo,
    String subject = TestFlightFeedbackCopy.emailSubject,
    String body = TestFlightFeedbackCopy.emailBody,
  }) {
    return Uri(
      scheme: 'mailto',
      path: to,
      query: _encodeQuery({'subject': subject, 'body': body}),
    );
  }

  static Future<bool> openFeedbackEmail() async {
    return launch(mailtoUri());
  }

  static Future<bool> launch(Uri uri) {
    final launch =
        launchUrlForTest ??
        ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
    return launch(uri);
  }

  static String _encodeQuery(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }
}

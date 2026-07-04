import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../share/archive_share_actions.dart';
import '../support/testflight_feedback_copy.dart';
import '../support/testflight_feedback_launcher.dart';
import 'beta_feedback_analytics.dart';
import 'beta_feedback_copy.dart';
import 'beta_feedback_model.dart';

/// Submits structured beta feedback via email or clipboard — no backend.
class BetaFeedbackController {
  const BetaFeedbackController({
    this.launchEmail,
    this.copyText,
    this.loadAppVersion,
  });

  @visibleForTesting
  final Future<bool> Function(Uri uri)? launchEmail;

  @visibleForTesting
  final Future<ArchiveShareOutcome> Function(BuildContext context, String text)?
      copyText;

  @visibleForTesting
  final Future<String> Function()? loadAppVersion;

  static Future<String> defaultAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  String buildMessage(BetaFeedbackSubmission submission) {
    return BetaFeedbackCopy.buildSubmissionMessage(
      surface: submission.source,
      optionLabel: submission.option.label,
      entryCount: submission.entryCount,
      appVersion: submission.appVersion,
      note: submission.note,
    );
  }

  /// Shows preview, then opens email or copies feedback text.
  Future<BetaFeedbackSubmitOutcome> submit({
    required BuildContext context,
    required BetaFeedbackSubmission submission,
  }) async {
    final message = buildMessage(submission);
    final confirmed = await _confirmSend(context, message);
    if (!confirmed) return BetaFeedbackSubmitOutcome.cancelled;

    BetaFeedbackAnalytics.submitted(
      source: submission.source,
      optionType: submission.option.analyticsKey,
      entryCount: submission.entryCount,
    );

    final uri = TestFlightFeedbackLauncher.mailtoUri(
      subject: TestFlightFeedbackCopy.emailSubject,
      body: message,
    );
    final opened = await _launchEmail(uri);

    if (opened) {
      if (context.mounted) {
        ArchiveShareActions.showFeedback(
          context,
          BetaFeedbackCopy.emailSentConfirmation,
        );
      }
      return BetaFeedbackSubmitOutcome.emailOpened;
    }

    if (!context.mounted) return BetaFeedbackSubmitOutcome.failed;
    final outcome = await _copyFeedback(context, message);
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(
        context,
        BetaFeedbackCopy.emailCopiedFallback,
      );
      return BetaFeedbackSubmitOutcome.copiedFallback;
    }
    return BetaFeedbackSubmitOutcome.failed;
  }

  Future<BetaFeedbackSubmission> buildSubmission({
    required String source,
    required BetaFeedbackOptionType option,
    required int entryCount,
    String? note,
  }) async {
    final versionLoader = loadAppVersion ?? defaultAppVersion;
    final appVersion = await versionLoader();
    return BetaFeedbackSubmission(
      source: source,
      option: option,
      entryCount: entryCount,
      appVersion: appVersion,
      note: _trimNote(note),
    );
  }

  Future<bool> _launchEmail(Uri uri) async {
    if (launchEmail != null) return launchEmail!(uri);
    final testLaunch = TestFlightFeedbackLauncher.launchUrlForTest;
    if (testLaunch != null) return testLaunch(uri);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<ArchiveShareOutcome> _copyFeedback(
    BuildContext context,
    String message,
  ) async {
    if (copyText != null) {
      return copyText!(context, message);
    }
    return ArchiveShareActions.copyShareText(
      context,
      text: message,
      showConfirmation: false,
    );
  }

  Future<bool> _confirmSend(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('beta_feedback_preview_dialog'),
        title: const Text(BetaFeedbackCopy.previewTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                BetaFeedbackCopy.previewBodyIntro,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                message,
                key: const Key('beta_feedback_preview_message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('beta_feedback_preview_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(BetaFeedbackCopy.sheetCancelCta),
          ),
          FilledButton(
            key: const Key('beta_feedback_preview_send'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(BetaFeedbackCopy.previewSendCta),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String? _trimNote(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length <= 500) return trimmed;
    return trimmed.substring(0, 500);
  }
}

import 'beta_feedback_models.dart';

/// Central copy for local beta feedback and proof surfaces.
abstract final class BetaFeedbackCopy {
  BetaFeedbackCopy._();

  static const cardTitle = 'Did ArchiveMe show you something useful?';
  static const cardBody =
      'Your archive is starting to compare moments. Your feedback helps improve '
      'the product.';

  static const usefulnessUseful = 'Yes, this was useful';
  static const usefulnessNotYet = 'Not yet';
  static const clarityUnderstood = 'I understood the idea';
  static const clarityConfused = 'I was confused';

  static const noteLabel = 'Optional note';
  static const noteHint = 'What helped or felt unclear? (optional)';

  static const saveButton = 'Save feedback';
  static const dismissButton = 'Not now';
  static const thanksMessage = 'Thanks — your feedback stays on this device only.';

  static const screenTitle = 'Beta feedback';
  static const screenIntro =
      'A local summary of your early archive progress and feedback. Nothing '
      'here is uploaded automatically.';

  static const summarySectionTitle = 'Beta proof summary';
  static const summaryMomentsSaved = 'Moments saved';
  static const summaryDepthLevel = 'Archive depth';
  static const summaryWatchThemes = 'Watch themes';
  static const summaryUsefulness = 'Usefulness';
  static const summaryClarity = 'Understanding';
  static const summaryNoPrivateEntries = 'No private entries shown here.';

  static const editSectionTitle = 'Update feedback';
  static const copySummaryButton = 'Copy feedback summary';
  static const copyTestimonialButton = 'Copy a short testimonial';
  static const summaryCopied = 'Feedback summary copied';
  static const testimonialCopied = 'Testimonial copied';

  static const supportSectionTitle = 'Beta feedback';
  static const supportSectionBody =
      'Share whether ArchiveMe felt useful after a few saved moments. '
      'Feedback stays on this device only.';
  static const openBetaFeedbackButton = 'Open beta feedback';

  static const testimonialDefault =
      'ArchiveMe helped me notice a pattern across my own saved moments.';
  static const testimonialUnderstood =
      'ArchiveMe made it easier to compare my own saved moments over time.';
  static const testimonialNotYet =
      'I am building an archive in ArchiveMe to see what repeats across my '
      'saved moments.';

  static const usefulnessNotAnswered = 'Not answered yet';
  static const clarityNotAnswered = 'Not answered yet';

  static String usefulnessLabel(BetaFeedbackUsefulness? value) {
    return switch (value) {
      BetaFeedbackUsefulness.useful => usefulnessUseful,
      BetaFeedbackUsefulness.notYet => usefulnessNotYet,
      null => usefulnessNotAnswered,
    };
  }

  static String clarityLabel(BetaFeedbackClarity? value) {
    return switch (value) {
      BetaFeedbackClarity.understood => clarityUnderstood,
      BetaFeedbackClarity.confused => clarityConfused,
      null => clarityNotAnswered,
    };
  }

  static String testimonialFor(BetaFeedbackState state) {
    if (state.usefulness == BetaFeedbackUsefulness.useful) {
      return testimonialDefault;
    }
    if (state.clarity == BetaFeedbackClarity.understood) {
      return testimonialUnderstood;
    }
    if (state.usefulness == BetaFeedbackUsefulness.notYet) {
      return testimonialNotYet;
    }
    return testimonialDefault;
  }

  static String buildSummaryText(BetaFeedbackSummary summary) {
    final buffer = StringBuffer()
      ..writeln('ArchiveMe beta feedback summary')
      ..writeln('')
      ..writeln('$summaryMomentsSaved: ${summary.momentsSavedCount}')
      ..writeln('$summaryDepthLevel: ${summary.depthLevelLabel}')
      ..writeln('$summaryWatchThemes: ${summary.watchThemesCount}')
      ..writeln('$summaryUsefulness: ${summary.usefulnessLabel}')
      ..writeln('$summaryClarity: ${summary.clarityLabel}')
      ..writeln('')
      ..writeln(summaryNoPrivateEntries);
    if (summary.feedbackState.note case final note?) {
      buffer
        ..writeln('')
        ..writeln('Note: $note');
    }
    return buffer.toString().trim();
  }

  static List<String> allVisibleCopy() => [
        cardTitle,
        cardBody,
        usefulnessUseful,
        usefulnessNotYet,
        clarityUnderstood,
        clarityConfused,
        noteLabel,
        noteHint,
        saveButton,
        dismissButton,
        thanksMessage,
        screenTitle,
        screenIntro,
        summarySectionTitle,
        summaryMomentsSaved,
        summaryDepthLevel,
        summaryWatchThemes,
        summaryUsefulness,
        summaryClarity,
        summaryNoPrivateEntries,
        editSectionTitle,
        copySummaryButton,
        copyTestimonialButton,
        summaryCopied,
        testimonialCopied,
        supportSectionTitle,
        supportSectionBody,
        openBetaFeedbackButton,
        testimonialDefault,
        testimonialUnderstood,
        testimonialNotYet,
        usefulnessNotAnswered,
        clarityNotAnswered,
      ];
}

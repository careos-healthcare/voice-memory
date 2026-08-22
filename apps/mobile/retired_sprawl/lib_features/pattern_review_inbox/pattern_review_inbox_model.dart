import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_model.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';

/// Review inbox item types — metadata only for analytics.
enum PatternReviewInboxItemType {
  firstProofTruth,
  whatChanged,
  patternCorrection,
  quietSignal,
  helpedTracking,
  patternRename;

  String get analyticsValue => switch (this) {
    PatternReviewInboxItemType.firstProofTruth => 'first_proof_truth',
    PatternReviewInboxItemType.whatChanged => 'what_changed',
    PatternReviewInboxItemType.patternCorrection => 'pattern_correction',
    PatternReviewInboxItemType.quietSignal => 'quiet_signal',
    PatternReviewInboxItemType.helpedTracking => 'helped_tracking',
    PatternReviewInboxItemType.patternRename => 'pattern_rename',
  };
}

enum PatternReviewInboxChip { needsCheck, optional, quietSignal }

/// One review item gathered from existing engines.
class PatternReviewInboxItem {
  const PatternReviewInboxItem({
    required this.type,
    required this.title,
    required this.body,
    required this.chip,
    this.proofKey,
    this.hasSnippets = false,
    this.whatChangedPrompt,
    this.patternCorrectionContext,
    this.quietSignal,
    this.helpedPrompt,
    this.patternNamePrompt,
  });

  final PatternReviewInboxItemType type;
  final String title;
  final String body;
  final PatternReviewInboxChip chip;
  final String? proofKey;
  final bool hasSnippets;
  final WhatChangedV2Prompt? whatChangedPrompt;
  final PatternCorrectionContext? patternCorrectionContext;
  final QuietSignal? quietSignal;
  final HelpedTrackingPrompt? helpedPrompt;
  final PatternNamePrompt? patternNamePrompt;
}

/// Full inbox result for card and sheet surfaces.
class PatternReviewInboxResult {
  const PatternReviewInboxResult({
    required this.items,
    required this.entryCount,
    this.previewItems = const [],
    this.hasMore = false,
  });

  final List<PatternReviewInboxItem> items;
  final List<PatternReviewInboxItem> previewItems;
  final int entryCount;
  final bool hasMore;

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.length;
}

/// Action payloads for inbox item handlers.
class PatternReviewInboxFirstProofAction {
  const PatternReviewInboxFirstProofAction({
    required this.proofKey,
    required this.answer,
  });

  final String proofKey;
  final FirstProofTruthAnswer answer;
}
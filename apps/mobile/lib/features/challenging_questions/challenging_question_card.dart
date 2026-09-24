import 'dart:async';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/challenging_questions/challenging_question_coordinator.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// One gentle question on the daily reflection surface.
class ChallengingQuestionCard extends StatefulWidget {
  const ChallengingQuestionCard({this.question, super.key});

  /// When set, the card shows this text instead of the stored question.
  final String? question;

  @override
  State<ChallengingQuestionCard> createState() =>
      _ChallengingQuestionCardState();
}

class _ChallengingQuestionCardState extends State<ChallengingQuestionCard> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _text = _clean(widget.question);
    if (widget.question != null) return;
    ChallengingQuestionCoordinator.addListener(_onPublished);
    unawaited(_loadStored());
  }

  @override
  void didUpdateWidget(ChallengingQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.question != oldWidget.question && widget.question != null) {
      _text = _clean(widget.question);
    }
  }

  @override
  void dispose() {
    if (widget.question == null) {
      ChallengingQuestionCoordinator.removeListener(_onPublished);
    }
    super.dispose();
  }

  void _onPublished() {
    final text = ChallengingQuestionCoordinator.latest?.text;
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _text = text);
  }

  Future<void> _loadStored() async {
    final published = ChallengingQuestionCoordinator.latest?.text;
    if (published != null && published.isNotEmpty) {
      if (mounted) setState(() => _text = published);
      return;
    }
    if (!AppServices.isInitialized) return;
    try {
      final stored = await ChallengingQuestionCoordinator.readStored();
      if (!mounted || stored == null) return;
      setState(() => _text = stored.text);
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Challenging question could not be read',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        key: const Key('challenging_question_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A question to sit with',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            key: const Key('challenging_question_text'),
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

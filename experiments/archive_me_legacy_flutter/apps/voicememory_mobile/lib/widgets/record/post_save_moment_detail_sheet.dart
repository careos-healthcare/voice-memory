import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../features/moment_quality/post_save_moment_detail_analytics.dart';
import '../../features/moment_quality/post_save_moment_detail_copy.dart';
import '../../features/moment_quality/post_save_moment_detail_model.dart';
import '../../features/moment_quality/post_save_moment_detail_service.dart';

/// Bottom sheet for adding one short post-save detail to a saved moment.
class PostSaveMomentDetailSheet extends StatefulWidget {
  const PostSaveMomentDetailSheet({
    super.key,
    required this.parentEntry,
    required this.detailType,
    required this.entryCount,
    this.service,
    this.initialText,
    this.saveDetailOverride,
  });

  final JournalEntry parentEntry;
  final PostSaveMomentDetailType detailType;
  final int entryCount;
  final PostSaveMomentDetailService? service;
  final String? initialText;

  /// Test-only hook to bypass [CapturePipelineService].
  @visibleForTesting
  final Future<JournalEntry> Function({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  })?
  saveDetailOverride;

  static Future<bool?> show(
    BuildContext context, {
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required int entryCount,
    PostSaveMomentDetailService? service,
  }) {
    unawaited(
      PostSaveMomentDetailAnalytics.promptTapped(
        detailType: detailType.analyticsValue,
        entryCount: entryCount,
      ),
    );
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PostSaveMomentDetailSheet(
          parentEntry: parentEntry,
          detailType: detailType,
          entryCount: entryCount,
          service: service,
        ),
      ),
    );
  }

  @override
  State<PostSaveMomentDetailSheet> createState() =>
      _PostSaveMomentDetailSheetState();
}

class _PostSaveMomentDetailSheetState extends State<PostSaveMomentDetailSheet> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  PostSaveMomentDetailService get _service =>
      widget.service ??
      PostSaveMomentDetailService(AppServices.instance.pipeline);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.saveDetailOverride != null) {
        await widget.saveDetailOverride!(
          parentEntry: widget.parentEntry,
          detailType: widget.detailType,
          detailText: text,
        );
      } else {
        await _service.saveDetail(
          parentEntry: widget.parentEntry,
          detailType: widget.detailType,
          detailText: text,
        );
      }
      if (!mounted) return;
      await PostSaveMomentDetailAnalytics.saved(
        detailType: widget.detailType.analyticsValue,
        entryCount: widget.entryCount,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CapturePipelineFailure {
      if (!mounted) return;
      await PostSaveMomentDetailAnalytics.failed(
        detailType: widget.detailType.analyticsValue,
        entryCount: widget.entryCount,
      );
      setState(() {
        _saving = false;
        _error = PostSaveMomentDetailCopy.saveFailedMessage;
      });
    } catch (_) {
      if (!mounted) return;
      await PostSaveMomentDetailAnalytics.failed(
        detailType: widget.detailType.analyticsValue,
        entryCount: widget.entryCount,
      );
      setState(() {
        _saving = false;
        _error = PostSaveMomentDetailCopy.saveFailedMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = PostSaveMomentDetailCopy.promptTitle(widget.detailType);
    final helper = PostSaveMomentDetailCopy.promptHelper(widget.detailType);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              key: Key('post_save_detail_title_${widget.detailType.name}'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              helper,
              key: Key('post_save_detail_helper_${widget.detailType.name}'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: Key('post_save_detail_field_${widget.detailType.name}'),
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: PostSaveMomentDetailCopy.detailFieldHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                key: const Key('post_save_detail_error'),
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: Key('post_save_detail_save_${widget.detailType.name}'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(PostSaveMomentDetailCopy.saveDetailCta),
            ),
            TextButton(
              key: Key('post_save_detail_cancel_${widget.detailType.name}'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text(PostSaveMomentDetailCopy.cancelCta),
            ),
          ],
        ),
      ),
    );
  }
}

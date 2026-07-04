import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/share_card/share_card_analytics.dart';
import '../../features/share_card/share_card_builder.dart';
import '../../features/share_card/share_card_copy.dart';
import '../../features/share_card/share_card_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'share_card_image.dart';

/// Confirmation + optional label edit before generating a private share image.
class ShareCardPreviewSheet extends StatefulWidget {
  const ShareCardPreviewSheet({
    super.key,
    required this.model,
    required this.source,
  });

  final ShareCardModel model;
  final String source;

  static Future<void> show(
    BuildContext context, {
    required ShareCardModel model,
    required String source,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ShareCardPreviewSheet(
          model: model,
          source: source,
        ),
      ),
    );
  }

  @override
  State<ShareCardPreviewSheet> createState() => _ShareCardPreviewSheetState();
}

class _ShareCardPreviewSheetState extends State<ShareCardPreviewSheet> {
  final _exportKey = GlobalKey();
  late final TextEditingController _labelController;
  bool _creating = false;

  ShareCardModel get _previewModel {
    final edited = ShareCardBuilder.sanitizeDisplayLabel(_labelController.text);
    if (edited == null) return widget.model;
    return widget.model.withDisplayLabel(edited);
  }

  bool get _canCreateImage {
    final label = ShareCardBuilder.sanitizeDisplayLabel(_labelController.text);
    return label != null && label.isNotEmpty && _previewModel.canShare;
  }

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.model.displayPatternLabel,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _createImage() async {
    if (_creating || !_canCreateImage) return;
    setState(() => _creating = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await ShareCardImage.sharePngViaSheet(
        boundaryKey: _exportKey,
        model: _previewModel,
      );
      ShareCardAnalytics.created(
        source: widget.source,
        hasChange: _previewModel.hasChangeNoticed,
        entryCount: _previewModel.entryCount,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create share image: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final showEdit = widget.model.labelNeedsReview;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('share_card_preview_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ShareCardCopy.confirmationTitle,
                key: const Key('share_card_preview_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ShareCardCopy.confirmationBody,
                key: const Key('share_card_preview_body'),
                style: bodyStyle.copyWith(color: AppColors.textSecondary),
              ),
              if (showEdit) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  ShareCardCopy.editLabelTitle,
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ShareCardCopy.editLabelHelper,
                  style: bodyStyle.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('share_card_edit_label_field'),
                  controller: _labelController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: ShareCardCopy.editLabelField,
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 80,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Center(
                child: ShareCardImage(
                  model: _previewModel,
                  exportKey: _exportKey,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('share_card_preview_cancel'),
                      onPressed: _creating
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(ShareCardCopy.cancelCta),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      key: const Key('share_card_preview_create_image'),
                      onPressed: _creating || !_canCreateImage
                          ? null
                          : _createImage,
                      child: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(ShareCardCopy.createImageCta),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/services/pod_api_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shown before any cover or margin control, and again beside the checkbox.
const podPrintConsentCopy =
    'To print your book, your generated PDF will be securely uploaded to our printing partner. It will be deleted immediately after your order is fulfilled.';

/// Consent first, then cover and margin choices. The PDF is not accepted
/// for upload until the checkbox is on and the upload button is pressed.
class PodCheckoutView extends StatefulWidget {
  const PodCheckoutView({required this.pdf, this.service, super.key});

  final Uint8List pdf;
  final PodApiService? service;

  @override
  State<PodCheckoutView> createState() => _PodCheckoutViewState();
}

class _PodCheckoutViewState extends State<PodCheckoutView> {
  late final PodApiService _service = widget.service ?? PodApiService();
  var _uploaded = false;
  var _cover = BookCover.softcover;
  var _margins = const BookMargins();
  var _ordered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showConsent();
    });
  }

  Future<void> _showConsent() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ConsentGate(
          onCancel: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).maybePop();
          },
          onUpload: () async {
            _service.grantUploadConsent();
            await _service.uploadPdfToPrinter(widget.pdf);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (mounted) setState(() => _uploaded = true);
          },
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    await _service.createPrintOrder(
      BookOptions(cover: _cover, margins: _margins),
    );
    if (mounted) setState(() => _ordered = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('pod_checkout_view'),
      appBar: AppBar(title: const Text('Printed book')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose how the book is made',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _uploaded
                ? 'The PDF is ready on this phone. Choose a cover, then save the order. Nothing is sent to a printer yet.'
                : 'Cover and margin choices stay closed until you agree to the upload.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_uploaded) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('pod_cover_softcover'),
                  label: const Text('Softcover'),
                  selected: _cover == BookCover.softcover,
                  onSelected: (_) =>
                      setState(() => _cover = BookCover.softcover),
                ),
                ChoiceChip(
                  key: const Key('pod_cover_hardcover'),
                  label: const Text('Hardcover'),
                  selected: _cover == BookCover.hardcover,
                  onSelected: (_) =>
                      setState(() => _cover = BookCover.hardcover),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Binding margin ${_margins.insideMm.round()} mm',
              style: theme.textTheme.titleSmall,
            ),
            Slider(
              key: const Key('pod_margin_inside'),
              min: 12,
              max: 30,
              divisions: 18,
              value: _margins.insideMm,
              label: '${_margins.insideMm.round()} mm',
              onChanged: (value) {
                setState(() => _margins = _margins.copyWith(insideMm: value));
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('pod_place_order'),
              onPressed: _ordered ? null : _placeOrder,
              child: const Text('Save print choices'),
            ),
            if (_ordered)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Choices saved on this phone. Nothing has been sent to a printer.',
                  key: const Key('pod_order_saved'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConsentGate extends StatefulWidget {
  const _ConsentGate({required this.onCancel, required this.onUpload});

  final VoidCallback onCancel;
  final Future<void> Function() onUpload;

  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  var _checked = false;
  var _busy = false;

  Future<void> _upload() async {
    setState(() => _busy = true);
    try {
      await widget.onUpload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('pod_consent_dialog'),
        title: const Text('Before your book is printed'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(podPrintConsentCopy),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('pod_consent_checkbox'),
                contentPadding: EdgeInsets.zero,
                value: _checked,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _checked = value ?? false),
                title: const Text('I agree to this upload'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('pod_upload_continue'),
                onPressed: _checked && !_busy ? _upload : null,
                child: const Text('Upload & Continue to Checkout'),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

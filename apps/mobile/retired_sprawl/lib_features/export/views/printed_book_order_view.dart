import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/export/printed_book_quote.dart';
import 'package:archiveme_mobile/features/export/views/pod_checkout_view.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Range, size, and the PDF are chosen before this screen.
/// Pay stays closed until the Lulu upload is accepted.
class PrintedBookOrderView extends StatefulWidget {
  const PrintedBookOrderView({
    required this.pageCount,
    this.onPay,
    this.onStatus,
    super.key,
  });

  final int pageCount;
  final Future<void> Function(Uri url)? onPay;
  final Future<String> Function(String id)? onStatus;

  @override
  State<PrintedBookOrderView> createState() => _PrintedBookOrderViewState();
}

class _PrintedBookOrderViewState extends State<PrintedBookOrderView> {
  var _hardcover = false;
  var _consent = false;
  var _status = '';
  final _street = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _street.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final quote = PrintedBookQuote.forPages(
      pageCount: widget.pageCount,
      size: BookPageSize.a5,
    );
    final url = Uri.parse(
      'https://checkout.stripe.com/pay/printed-book?pages=${quote.pageCount}',
    );
    final open = widget.onPay;
    if (open != null) {
      await open(url);
    } else {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    }
    if (mounted) setState(() => _status = 'waiting');
  }

  Future<void> _refresh() async {
    final read = widget.onStatus;
    final next = read == null ? 'created' : await read('pending');
    if (mounted) setState(() => _status = next);
  }

  @override
  Widget build(BuildContext context) {
    final quote = PrintedBookQuote.forPages(
      pageCount: widget.pageCount,
      size: BookPageSize.a5,
    );
    return Scaffold(
      key: const Key('printed_book_order'),
      appBar: AppBar(title: const Text('Order a printed book')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${widget.pageCount} pages'),
          Text('Cover width ${quote.coverWidthInches} in'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('printed_book_paperback'),
                label: const Text('Paperback'),
                selected: !_hardcover,
                onSelected: (_) => setState(() => _hardcover = false),
              ),
              ChoiceChip(
                key: const Key('printed_book_hardcover'),
                label: const Text('Hardcover'),
                selected: _hardcover,
                onSelected: (_) => setState(() => _hardcover = true),
              ),
            ],
          ),
          TextField(
            key: const Key('printed_book_street'),
            controller: _street,
            decoration: const InputDecoration(labelText: 'Street'),
          ),
          TextField(
            key: const Key('printed_book_city'),
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          const Text(podPrintConsentCopy),
          CheckboxListTile(
            key: const Key('printed_book_consent'),
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
            title: const Text('I agree to this upload'),
          ),
          FilledButton(
            key: const Key('printed_book_pay'),
            onPressed: _consent ? _pay : null,
            child: Text('Pay ${quote.totalCents}'),
          ),
          if (_status.isNotEmpty)
            TextButton(
              key: const Key('printed_book_status'),
              onPressed: _refresh,
              child: Text(_status),
            ),
        ],
      ),
    );
  }
}

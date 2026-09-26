import 'package:archiveme_mobile/features/sync/services/device_pairing_service.dart';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Shows a pairing QR, or accepts a code scanned from another phone.
class DevicePairingView extends StatefulWidget {
  const DevicePairingView({
    required this.service,
    required this.masterKey,
    required this.salt,
    super.key,
  });

  final DevicePairingService service;
  final List<int> masterKey;
  final List<int> salt;

  @override
  State<DevicePairingView> createState() => _DevicePairingViewState();
}

class _DevicePairingViewState extends State<DevicePairingView> {
  final _code = TextEditingController();
  EphemeralPairingOffer? _offer;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _showCode() async {
    final offer = await widget.service.createPairingOffer();
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _message = null;
    });
  }

  Future<void> _finish() async {
    final offer = _offer;
    if (offer == null) return;
    try {
      await widget.service.finishPairing(offer: offer);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PairingExpired {
      setState(() => _message = 'This pairing code has expired.');
    } on PairingNotAuthentic {
      setState(() => _message = 'This pairing transfer could not be verified.');
    } on Object {
      setState(() => _message = 'The linked key is not ready yet.');
    }
  }

  Future<void> _send() async {
    try {
      await widget.service.sendAccountKey(
        scannedPayload: _code.text,
        accountKey: widget.masterKey,
        salt: widget.salt,
      );
      if (!mounted) return;
      setState(() => _message = 'The key was sent to the new phone.');
    } on PairingExpired {
      setState(() => _message = 'This pairing code has expired.');
    } on Object {
      setState(() => _message = 'This pairing code could not be read.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    return Scaffold(
      key: const Key('device_pairing_view'),
      appBar: AppBar(title: const Text('Link a new device')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'On the new phone, show a code. On the phone that already syncs, paste that code so it can send the key. Then finish linking on the new phone. The code expires in five minutes.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('pairing_show_code'),
            onPressed: _showCode,
            child: const Text('Show pairing code'),
          ),
          if (offer != null) ...[
            const SizedBox(height: 16),
            Center(
              child: PairingQr(
                key: const Key('pairing_qr'),
                data: offer.payload,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(offer.payload, key: const Key('pairing_payload')),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('pairing_finish'),
              onPressed: _finish,
              child: const Text('Finish linking'),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            key: const Key('pairing_code_input'),
            controller: _code,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Code from the new phone',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('pairing_accept'),
            onPressed: _send,
            child: const Text('Send the key to that phone'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, key: const Key('pairing_message')),
          ],
        ],
      ),
    );
  }
}

class PairingQr extends StatelessWidget {
  const PairingQr({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    return CustomPaint(
      size: const Size(220, 220),
      painter: _QrPainter(image),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final cell = size.width / image.moduleCount;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.image != image;
}

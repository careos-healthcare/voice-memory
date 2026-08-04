import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DevicePairingScanner extends StatefulWidget {
  const DevicePairingScanner({super.key, required this.onPayload});

  final ValueChanged<String> onPayload;

  @override
  State<DevicePairingScanner> createState() => _DevicePairingScannerState();
}

class _DevicePairingScannerState extends State<DevicePairingScanner> {
  var _handled = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan pairing code')),
    body: Semantics(
      label: 'Camera scanner for an encrypted ArchiveMe pairing code',
      child: MobileScanner(
        key: const Key('device-pairing-scanner'),
        onDetect: (capture) {
          if (_handled) return;
          final payload = capture.barcodes
              .map((item) => item.rawValue)
              .whereType<String>()
              .firstOrNull;
          if (payload == null || payload.isEmpty) return;
          _handled = true;
          widget.onPayload(payload);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
}

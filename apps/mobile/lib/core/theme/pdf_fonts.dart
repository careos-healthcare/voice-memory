import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Serif faces for the printable journal.
abstract final class PdfFonts {
  PdfFonts._();

  static pw.Font? _regular;
  static pw.Font? _italic;
  static pw.Font? _inter;

  /// Small labels above an entry. Falls back to Newsreader if Inter will not load.
  static Future<pw.Font> inter(pw.Font fallback) async {
    if (_inter != null) return _inter!;
    try {
      _inter = pw.Font.ttf(await _bytes('assets/fonts/Inter-Variable.ttf'));
      return _inter!;
    } on Object {
      return fallback;
    }
  }

  static Future<pw.Font> newsreader() async {
    _regular ??= pw.Font.ttf(
      await _bytes('assets/fonts/Newsreader-Regular.ttf'),
    );
    return _regular!;
  }

  static Future<pw.Font> newsreaderItalic() async {
    _italic ??= pw.Font.ttf(
      await _bytes('assets/fonts/Newsreader-Italic.ttf'),
    );
    return _italic!;
  }

  static Future<ByteData> _bytes(String asset) async {
    try {
      return await rootBundle.load(asset);
    } on Object {
      final data = await File(asset).readAsBytes();
      return ByteData.sublistView(data);
    }
  }
}

import 'dart:typed_data';

/// Embeds PNG tEXt metadata chunks before IEND for referral attribution.
abstract final class InsightSharePngMetadata {
  InsightSharePngMetadata._();

  static final List<int> _crcTable = _buildCrcTable();

  static Uint8List embedReferralMetadata(
    Uint8List pngBytes, {
    required String referralUrl,
    required String source,
  }) {
    return embedTextMetadata(pngBytes, {
      'ArchiveMeReferral': referralUrl,
      'ArchiveMeSource': source,
    });
  }

  static Uint8List embedTextMetadata(
    Uint8List pngBytes,
    Map<String, String> entries,
  ) {
    final iendOffset = _findIendOffset(pngBytes);
    final chunks = entries.entries.map((e) => _buildTextChunk(e.key, e.value));
    final extraLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final output = Uint8List(pngBytes.length + extraLength);
    output.setRange(0, iendOffset, pngBytes.sublist(0, iendOffset));
    var cursor = iendOffset;
    for (final chunk in chunks) {
      output.setRange(cursor, cursor + chunk.length, chunk);
      cursor += chunk.length;
    }
    output.setRange(cursor, cursor + (pngBytes.length - iendOffset),
        pngBytes.sublist(iendOffset));
    return output;
  }

  static int _findIendOffset(Uint8List png) {
    for (var i = png.length - 12; i >= 8; i--) {
      if (png[i + 4] == 0x49 &&
          png[i + 5] == 0x45 &&
          png[i + 6] == 0x4E &&
          png[i + 7] == 0x44) {
        return i;
      }
    }
    throw StateError('PNG IEND chunk not found');
  }

  static Uint8List _buildTextChunk(String keyword, String text) {
    final keywordBytes = Uint8List.fromList(keyword.codeUnits);
    final textBytes = Uint8List.fromList(text.codeUnits);
    final data = Uint8List(keywordBytes.length + 1 + textBytes.length);
    data.setRange(0, keywordBytes.length, keywordBytes);
    data[keywordBytes.length] = 0;
    data.setRange(keywordBytes.length + 1, data.length, textBytes);

    const type = [0x74, 0x45, 0x58, 0x74]; // tEXt
    final crcInput = Uint8List(type.length + data.length)
      ..setRange(0, type.length, type)
      ..setRange(type.length, type.length + data.length, data);

    final chunk = Uint8List(4 + type.length + data.length + 4);
    _writeU32(chunk, 0, data.length);
    chunk.setRange(4, 8, type);
    chunk.setRange(8, 8 + data.length, data);
    _writeU32(chunk, 8 + data.length, _crc32(crcInput));
    return chunk;
  }

  static void _writeU32(Uint8List target, int offset, int value) {
    target[offset] = value & 0xff;
    target[offset + 1] = (value >> 8) & 0xff;
    target[offset + 2] = (value >> 16) & 0xff;
    target[offset + 3] = (value >> 24) & 0xff;
  }

  static int _crc32(Uint8List bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  static List<int> _buildCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c;
    }
    return table;
  }
}
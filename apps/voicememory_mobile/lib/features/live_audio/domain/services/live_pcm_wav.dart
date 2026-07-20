import 'dart:typed_data';

/// Wraps raw 16-bit LE mono PCM in a minimal WAV container for playback.
Uint8List wrapPcm16LeMonoInWav(
  List<int> pcmBytes, {
  required int sampleRateHz,
  int numChannels = 1,
}) {
  final dataSize = pcmBytes.length;
  final byteRate = sampleRateHz * numChannels * 2;
  final blockAlign = numChannels * 2;
  final fileSize = 36 + dataSize;

  final header = BytesBuilder(copy: false);
  header.add('RIFF'.codeUnits);
  header.add(_le32(fileSize));
  header.add('WAVE'.codeUnits);
  header.add('fmt '.codeUnits);
  header.add(_le32(16));
  header.add(_le16(1));
  header.add(_le16(numChannels));
  header.add(_le32(sampleRateHz));
  header.add(_le32(byteRate));
  header.add(_le16(blockAlign));
  header.add(_le16(16));
  header.add('data'.codeUnits);
  header.add(_le32(dataSize));
  header.add(pcmBytes);
  return header.toBytes();
}

List<int> _le16(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _le32(int value) => [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];

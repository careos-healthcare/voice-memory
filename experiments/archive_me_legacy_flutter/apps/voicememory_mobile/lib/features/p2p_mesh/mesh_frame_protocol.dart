import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mesh_models.dart';

class MeshProtocolException implements Exception {
  const MeshProtocolException(this.message);

  final String message;

  @override
  String toString() => 'MeshProtocolException: $message';
}

class MeshFrame {
  MeshFrame({
    required this.type,
    required this.sequence,
    required List<int> payload,
  }) : payload = Uint8List.fromList(payload);

  final int type;
  final int sequence;
  final Uint8List payload;
}

class MeshFrameCipher {
  MeshFrameCipher({
    required MeshSessionKeys keys,
    this.maxPlaintextBytes = 1024 * 1024,
  }) : _sendKey = SecretKey(keys.sendKey),
       _receiveKey = SecretKey(keys.receiveKey),
       _sendNoncePrefix = Uint8List.fromList(keys.sendNoncePrefix),
       _receiveNoncePrefix = Uint8List.fromList(keys.receiveNoncePrefix) {
    if (maxPlaintextBytes < 1 || maxPlaintextBytes > 16 * 1024 * 1024) {
      throw ArgumentError.value(maxPlaintextBytes, 'maxPlaintextBytes');
    }
  }

  static const _magic0 = 0x56;
  static const _magic1 = 0x4d;
  static const _version = 1;
  static const _headerLength = 28;
  static const _tagLength = 16;

  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final Uint8List _sendNoncePrefix;
  final Uint8List _receiveNoncePrefix;
  final int maxPlaintextBytes;
  final AesGcm _cipher = AesGcm.with256bits();
  int _nextSendSequence = 0;
  int _nextReceiveSequence = 0;

  int get nextSendSequence => _nextSendSequence;
  int get nextReceiveSequence => _nextReceiveSequence;
  int get maxPacketBytes => _headerLength + maxPlaintextBytes + _tagLength;

  Future<Uint8List> encrypt({
    required int type,
    required List<int> payload,
  }) async {
    if (type < 0 || type > 255) {
      throw ArgumentError.value(type, 'type', 'Expected an unsigned byte.');
    }
    if (payload.length > maxPlaintextBytes) {
      throw MeshProtocolException(
        'Frame payload exceeds $maxPlaintextBytes bytes.',
      );
    }
    if (_nextSendSequence >= 0x7fffffffffffffff) {
      throw const MeshProtocolException('Send sequence exhausted.');
    }
    final sequence = _nextSendSequence;
    final nonce = _nonce(_sendNoncePrefix, sequence);
    final header = _header(
      type: type,
      sequence: sequence,
      ciphertextLength: payload.length,
      nonce: nonce,
    );
    final box = await _cipher.encrypt(
      payload,
      secretKey: _sendKey,
      nonce: nonce,
      aad: header,
    );
    _nextSendSequence++;
    return Uint8List.fromList([...header, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<MeshFrame> decrypt(List<int> packet) async {
    if (packet.length < _headerLength + _tagLength) {
      throw const MeshProtocolException('Truncated mesh frame.');
    }
    final bytes = Uint8List.fromList(packet);
    final data = ByteData.sublistView(bytes);
    if (bytes[0] != _magic0 || bytes[1] != _magic1 || bytes[2] != _version) {
      throw const MeshProtocolException('Invalid mesh frame header.');
    }
    final type = bytes[3];
    final sequence = data.getUint64(4);
    final ciphertextLength = data.getUint32(12);
    if (ciphertextLength > maxPlaintextBytes) {
      throw MeshProtocolException(
        'Frame payload exceeds $maxPlaintextBytes bytes.',
      );
    }
    final expectedLength = _headerLength + ciphertextLength + _tagLength;
    if (bytes.length != expectedLength) {
      throw const MeshProtocolException('Invalid mesh frame length.');
    }
    if (sequence != _nextReceiveSequence) {
      throw MeshProtocolException(
        sequence < _nextReceiveSequence
            ? 'Replayed mesh frame.'
            : 'Out-of-order mesh frame.',
      );
    }
    final nonce = bytes.sublist(16, _headerLength);
    final expectedNonce = _nonce(_receiveNoncePrefix, sequence);
    if (!_constantTimeEquals(nonce, expectedNonce)) {
      throw const MeshProtocolException('Invalid mesh frame nonce.');
    }
    final ciphertextEnd = _headerLength + ciphertextLength;
    final cleartext = await _cipher.decrypt(
      SecretBox(
        bytes.sublist(_headerLength, ciphertextEnd),
        nonce: nonce,
        mac: Mac(bytes.sublist(ciphertextEnd)),
      ),
      secretKey: _receiveKey,
      aad: bytes.sublist(0, _headerLength),
    );
    _nextReceiveSequence++;
    return MeshFrame(type: type, sequence: sequence, payload: cleartext);
  }

  static int packetLengthFromPrefix(
    List<int> prefix, {
    int maxPlaintextBytes = 1024 * 1024,
  }) {
    if (prefix.length < 16) return 0;
    if (prefix[0] != _magic0 || prefix[1] != _magic1 || prefix[2] != _version) {
      throw const MeshProtocolException('Invalid mesh frame header.');
    }
    final length = ByteData.sublistView(
      Uint8List.fromList(prefix),
    ).getUint32(12);
    if (length > maxPlaintextBytes) {
      throw MeshProtocolException(
        'Frame payload exceeds $maxPlaintextBytes bytes.',
      );
    }
    return _headerLength + length + _tagLength;
  }

  Uint8List _header({
    required int type,
    required int sequence,
    required int ciphertextLength,
    required List<int> nonce,
  }) {
    final header = Uint8List(_headerLength);
    final data = ByteData.sublistView(header);
    header[0] = _magic0;
    header[1] = _magic1;
    header[2] = _version;
    header[3] = type;
    data.setUint64(4, sequence);
    data.setUint32(12, ciphertextLength);
    header.setRange(16, _headerLength, nonce);
    return header;
  }

  Uint8List _nonce(List<int> prefix, int sequence) {
    final nonce = Uint8List(12)..setRange(0, 4, prefix);
    ByteData.sublistView(nonce).setUint64(4, sequence);
    return nonce;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  void destroy() {
    _sendKey.destroy();
    _receiveKey.destroy();
    _sendNoncePrefix.fillRange(0, _sendNoncePrefix.length, 0);
    _receiveNoncePrefix.fillRange(0, _receiveNoncePrefix.length, 0);
  }
}

class MeshFrameBuffer {
  MeshFrameBuffer({this.maxPacketBytes = 1024 * 1024 + 44});

  final int maxPacketBytes;
  final List<int> _buffer = [];

  List<Uint8List> add(List<int> chunk) {
    if (_buffer.length + chunk.length > maxPacketBytes * 2) {
      _buffer.clear();
      throw const MeshProtocolException('Mesh receive buffer limit exceeded.');
    }
    _buffer.addAll(chunk);
    final packets = <Uint8List>[];
    while (_buffer.length >= 16) {
      final length = MeshFrameCipher.packetLengthFromPrefix(
        _buffer,
        maxPlaintextBytes: maxPacketBytes - 44,
      );
      if (length > maxPacketBytes) {
        _buffer.clear();
        throw const MeshProtocolException('Mesh packet limit exceeded.');
      }
      if (_buffer.length < length) break;
      packets.add(Uint8List.fromList(_buffer.sublist(0, length)));
      _buffer.removeRange(0, length);
    }
    return packets;
  }
}

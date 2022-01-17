import 'dart:typed_data';

import 'package:ryze_tello/src/modules/utilities/numbers.dart';

import 'crc.dart';

class PacketType {
  final int _value;

  const PacketType._(this._value);

  static const PacketType get = PacketType._(1);
  static const PacketType data1 = PacketType._(2);
  static const PacketType data2 = PacketType._(4);
  static const PacketType command = PacketType._(5);
  static const PacketType flipCommand = PacketType._(6);
}

class Command {
  final int _value;

  const Command._(this._value);

  static const Command takeoff = Command._(0x0054);
}

class Packet {
  // [header = 0xcc, packetSize, sizeCrc (crc8), [toDrone, fromDrone, packetType, packetSubtype], command, sequence, ...payload, packetCrc (crc16)]

  static const int minimumPacketSize = 11;

  final PacketType _packetType; // 3 bit
  final bool _toDrone;
  final Command _command; // 2 bytes (little endian)
  final int _sequence; // 2 bytes (little endian) (usually 0)
  final Uint8List _payload; // varying bytes (optional)

  Packet(this._command,
      {PacketType packetType = PacketType.command,
      int sequence = 0,
      Uint8List? payload})
      : _packetType = packetType,
        _toDrone = true,
        _sequence = sequence,
        _payload = payload ?? Uint8List(0);

  void pushByte(int byte) => _payload.add(byte);
  void pushAll(Uint8List bytes) => _payload.addAll(bytes);
  int popByte() => _payload.removeLast();

  Uint8List get bufffer {
    int payloadSize = _payload.length;
    int packetSize = minimumPacketSize + payloadSize;

    int command = _command._value;

    Uint8List bytes = Uint8List.fromList([
      0xcc,
      packetSize << 3,
      packetSize >> 5,
      0, // Will be crc8 later
      (_packetType._value << 3) | ((_toDrone) ? 0x40 : 0x80),
      command,
      command >> 8,
      _sequence,
      _sequence >> 8,
      ..._payload,
    ]);

    int crc8 = calculateCrc8(bytes.sublist(0, 3));
    bytes[3] = crc8;

    int crc16 = calculateCrc16(bytes);
    bytes.addAll([crc16, crc16 >> 8]);

    return bytes;
  }
}

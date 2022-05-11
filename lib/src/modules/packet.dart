import 'dart:typed_data';

import 'package:handy/handy.dart';

import 'crc.dart';

enum PacketType { get, data1, data2, command, flipCommand }

extension PacketTypeExtension on PacketType {
  static final Map<int, PacketType> _valueMapping = {
    for (PacketType type in PacketType.values) type._value: type
  };

  int get _value {
    return index + ((index <= 1) ? 1 : 2);
  }

  static PacketType fromValue(int value) {
    return _valueMapping[value]!;
  }
}

enum Command { takeoff, land, flightStatus }

extension CommandExtension on Command {
  static final Map<int, Command> _valueMapping = {
    for (Command type in Command.values) type._value: type
  };

  int get _value {
    switch (this) {
      case (Command.takeoff):
        {
          return 0x0054;
        }

      case (Command.land):
        {
          return 0x0055;
        }

      case (Command.flightStatus):
        {
          return 0x0056;
        }

      default:
        {
          throw UnimplementedError("Unknown command '${toShortString()}'");
        }
    }
  }

  static Command fromValue(int value) {
    return _valueMapping[value]!;
  }
}

class Packet {
  // [header = 0xcc, packetSize, sizeCrc (crc8), [toDrone, fromDrone, packetType, packetSubtype], command, sequence, ...payload, packetCrc (crc16)]

  final bool _toDrone;
  final PacketType _packetType; // 3 bit
  final Command _command; // 2 bytes (little endian)
  final int _sequence; // 2 bytes (little endian) (usually 0)
  final Uint8List _payload; // varying bytes (optional)

  Packet(this._command,
      {int sequence = 0,
      PacketType packetType = PacketType.command,
      Uint8List? payload})
      : _toDrone = true,
        _packetType = packetType,
        _sequence = sequence,
        _payload = payload ?? Uint8List(0);

  Packet.fromBuffer(Uint8List bytes)
      : _toDrone = (bytes[4] & 0x40) == 1,
        _packetType = PacketTypeExtension.fromValue((bytes[4] >> 3) & 0x07),
        _command = CommandExtension.fromValue((bytes[6] << 8) | bytes[5]),
        _sequence = ((bytes[8]) << 8) | (bytes[7]),
        _payload = bytes.sublist(9, bytes.length - 2) {
    int crc8Validation = calculateCrc8(buffer.sublist(0, 4));
    int crc16Validation = calculateCrc16(bytes);

    if (crc8Validation != 0 || crc16Validation != 0) {
      throw FormatException(
          "The packet buffer '$buffer' failed to be validated with crcs");
    }
  }

  Uint8List get buffer {
    int payloadSize = _payload.length;
    int packetSize = 11 + payloadSize;

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
      0, // Will be the first byte of crc 16 later
      0 // Will be the second byte of crc 16 later
    ]);

    int crc8 = calculateCrc8(bytes.sublist(0, 3));
    bytes[3] = crc8;

    int packetEnd = bytes.length - 2;

    int crc16 = calculateCrc16(bytes.sublist(0, packetEnd));
    bytes[packetEnd] = crc16;
    bytes[packetEnd + 1] = crc16 >> 8;

    return bytes;
  }

  @override
  String toString() =>
      "$Packet(toDrone: $_toDrone, packetType: ${_packetType.toShortString()}, command: ${_command.toShortString()}, sequence: $_sequence, payload: $_payload)";
}

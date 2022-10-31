import 'dart:typed_data';

import 'package:handy/handy.dart';

import 'crc.dart';

enum PacketType { get, data1, data2, command, flipCommand }

extension PacketTypeExtension on PacketType {
  static final Map<int, PacketType> _valueMapping = {
    for (var type in PacketType.values) type._value: type
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
    for (var type in Command.values) type._value: type
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

  final bool toDrone;
  final PacketType packetType; // 3 bit
  final Command command; // 2 bytes (little endian)
  final int sequence; // 2 bytes (little endian) (usually 0)
  final Uint8List payload; // varying bytes (optional)

  late final Uint8List buffer;

  Packet(this.command,
      {this.toDrone = true,
      this.packetType = PacketType.command,
      this.sequence = 0,
      List<int> payload = const []})
      : payload = Uint8List.fromList(payload) {
    buffer =
        _createBuffer(this.payload, command, packetType, toDrone, sequence);
  }

  Packet.fromBuffer(Uint8List bytes)
      : toDrone = (() {
          // Checks if the bit that indicates that it's to the drone is set.
          // https://stackoverflow.com/questions/32188992/get-second-most-significant-bit-of-a-number
          final packetInfo = bytes[4];
          return packetInfo > (packetInfo ^ (packetInfo >> 1));
        })(),
        packetType = PacketTypeExtension.fromValue((bytes[4] >> 3) & 0x07),
        command = CommandExtension.fromValue((bytes[6] << 8) | bytes[5]),
        sequence = ((bytes[8]) << 8) | (bytes[7]),
        payload = bytes.sublist(9, bytes.length - 2) {
    buffer = _createBuffer(payload, command, packetType, toDrone, sequence);

    final crc8Validation = calculateCrc8(buffer.sublist(0, 4));

    final crc16Validation = calculateCrc16(bytes);

    if (crc8Validation != 0 || crc16Validation != 0) {
      throw FormatException("The CRC validation for buffer '$buffer' failed.");
    }
  }

  static Uint8List _createBuffer(Uint8List payload, Command command,
      PacketType packetType, bool toDrone, int sequence) {
    final payloadSize = payload.length;
    final packetSize = 11 + payloadSize;

    final commandId = command._value;

    final bytes = Uint8List.fromList([
      0xcc,
      packetSize << 3,
      packetSize >> 5,
      0, // Will be crc8 later
      (packetType._value << 3) | ((toDrone) ? 0x40 : 0x80),
      commandId,
      commandId >> 8,
      sequence,
      sequence >> 8,
      ...payload,
      0, // Will be the first byte of crc 16 later
      0 // Will be the second byte of crc 16 later
    ]);

    final crc8 = calculateCrc8(bytes.sublist(0, 3));
    bytes[3] = crc8;

    final packetEnd = bytes.length - 2;

    final crc16 = calculateCrc16(bytes.sublist(0, packetEnd));
    bytes[packetEnd] = crc16;
    bytes[packetEnd + 1] = crc16 >> 8;

    return bytes;
  }

  @override
  String toString() =>
      "$Packet(toDrone: $toDrone, packetType: ${packetType.toShortString()}, command: ${command.toShortString()}, sequence: $sequence, payload: $payload)";
}

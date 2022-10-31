import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ryze_tello/src/modules/packet.dart';

import 'modules/error.dart';
import 'modules/socket.dart';

/// Directions that the tello can fly in.
enum FlyDirection { forward, back, left, right, up, down }

/// Directions that the tello can flip toward.
enum FlipDirection { front, back, left, right }

/// Holds [pitch], [roll], and [yaw] data from the Tello.
class IMUAttitude {
  final int pitch;
  final int roll;
  final int yaw;

  const IMUAttitude(this.pitch, this.roll, this.yaw);

  @override
  String toString() => "$IMUAttitude(pitch: $pitch, roll: $roll, yaw: $yaw)";
}

/// Holds acceleration data from the Tello.
class IMUAcceleration {
  final double xAcceleration;
  final double yAcceleration;
  final double zAcceleration;

  const IMUAcceleration(
      this.xAcceleration, this.yAcceleration, this.zAcceleration);

  @override
  String toString() =>
      "$IMUAcceleration(xAcceleration: $xAcceleration, yAcceleration: $yAcceleration, zAcceleration: $zAcceleration)";
}

/// Holds velocity data from the Tello.
class IMUVelocity {
  final int xVelocity;
  final int yVelocity;
  final int zVelocity;

  const IMUVelocity(this.xVelocity, this.yVelocity, this.zVelocity);

  @override
  String toString() =>
      "$IMUAcceleration(xVelocity: $xVelocity, yVelocity: $yVelocity, zVelocity: $zVelocity)";
}

/// Holds data from the Tello's current state.
class TelloState {
  final IMUAttitude imuAttitude;
  final IMUVelocity imuVelocity;
  final double averageTemperature;
  final int distanceFromTakeoff;
  final int height;
  final int battery;
  final double barometerReading;
  final int flightTime;
  final IMUAcceleration imuAcceleration;

  const TelloState(
    this.imuAttitude,
    this.imuVelocity,
    this.imuAcceleration,
    this.averageTemperature,
    this.distanceFromTakeoff,
    this.height,
    this.battery,
    this.barometerReading,
    this.flightTime,
  );

  @override
  String toString() => "$TelloState\n(\n\t${{
        "imuAttitude": imuAttitude,
        "imuVelocity": imuVelocity,
        "imuAcceleration": imuAcceleration,
        "averageTemperature": averageTemperature,
        "distanceFromTakeoff": distanceFromTakeoff,
        "height": height,
        "battery": battery,
        "barometerReading": barometerReading,
        "flightTime": flightTime,
      }.entries.map((element) => '${element.key}: ${element.value}').join('\n\t')}\n)";
}

/// Represents the Tello in your code.
class Tello {
  final TelloSocket _connection;
  final TelloSocket _stateReceiver;

  int commandSequence = 1;

  /// Serves as the constructor for the Tello class, is a static method because constructors can't be asynchronous.
  static Future<Tello> tello(
      {Duration timeout = const Duration(seconds: 12),
      Address? telloAddress,
      Address? localAddress,
      Address? stateReceiverAddress,
      int videoPort = 11111}) async {
    stateReceiverAddress = stateReceiverAddress ??
        Address(ip: InternetAddress.anyIPv4, port: 8890);

    final sockets = await Future.wait([
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          localAddress: localAddress,
          timeout: timeout),
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          localAddress: stateReceiverAddress,
          timeout: timeout)
    ]);

    final tello = Tello._(sockets[0], sockets[1]);

    await tello._connect(videoPort);

    return tello;
  }

  Tello._(this._connection, this._stateReceiver);

  Future<void> _connect(int videoPort) async {
    final response = await _connection.command(Uint8List.fromList(
        [...utf8.encode("conn_req:"), videoPort, videoPort >> 8]));

    final acknowledgement = Uint8List.fromList(utf8.encode("conn_ack:"));

    for (int i = 0; i < acknowledgement.length; i++) {
      if (response[i] != acknowledgement[i]) {
        throw TelloError("Couldn't connect to the tello successfully.");
      }
    }
  }

  Future<void> _command(Command command,
          {PacketType packetType = PacketType.command,
          List<int> payload = const []}) async =>
      _connection.send(Packet(command,
              sequence: commandSequence++,
              /* This increment is a bit weird in this context,
                 but it's basically a one-liner that returns
                 the current value of [commandSequence] and
                 then increments it after. */
              packetType: packetType,
              payload: payload)
          .buffer);

  /// Asks the Tello to takeoff.
  Future<void> takeoff() async =>
      _command(Command.takeoff); //_command(Command.takeoff);

  /// Asks the Tello to land.
  Future<void> land() => _command(Command.land, payload: [0x00]);

  /// Closes sockets that connect to the Tello and cancels any lingering listeners to the Tello's state.
  void disconnect() {
    _connection.disconnect();
    _stateReceiver.disconnect();
  }
}

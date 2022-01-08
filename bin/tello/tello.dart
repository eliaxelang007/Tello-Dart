import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'modules/utilities/enums.dart';

import 'modules/socket.dart';
import 'modules/error.dart';

enum FlyDirection { forward, back, left, right, up, down }
enum FlipDirection { front, back, left, right }

class IMUAttitude {
  final int pitch;
  final int roll;
  final int yaw;

  const IMUAttitude(this.pitch, this.roll, this.yaw);

  @override
  String toString() => "$IMUAttitude(pitch: $pitch, roll: $roll, yaw: $yaw)";
}

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

class IMUVelocity {
  final int xVelocity;
  final int yVelocity;
  final int zVelocity;

  const IMUVelocity(this.xVelocity, this.yVelocity, this.zVelocity);

  @override
  String toString() =>
      "$IMUAcceleration(xVelocity: $xVelocity, yVelocity: $yVelocity, zVelocity: $zVelocity)";
}

class TelloState {
  final IMUAttitude imuAttitude;
  final IMUVelocity imuVelocity;
  final double averageTemprature;
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
    this.averageTemprature,
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
        "averageTemprature": averageTemprature,
        "distanceFromTakeoff": distanceFromTakeoff,
        "height": height,
        "battery": battery,
        "barometerReading": barometerReading,
        "flightTime": flightTime,
      }.entries.map((element) => '${element.key}: ${element.value}').join('\n\t')}\n)";
}

String _parse(Uint8List command) => utf8.decode(command).trim();

class Tello {
  final TelloSocket _client;
  final TelloSocket _stateReceiver;

  static Future<Tello> tello({
    Duration timeout = const Duration(seconds: 12),
    Address? telloAddress,
    Address? clientAddress,
    Address? stateReceiverAddress,
  }) async {
    stateReceiverAddress = stateReceiverAddress ??
        Address(ip: InternetAddress.anyIPv4, port: 8890);

    List<TelloSocket> sockets = await Future.wait([
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          clientAddress: clientAddress,
          timeout: timeout),
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          clientAddress: stateReceiverAddress,
          timeout: timeout)
    ]);

    Tello tello = Tello._(sockets[0], sockets[1]);

    await tello._command("command");
    //await tello._stateReceiver.responses.first;

    return tello;
  }

  Tello._(this._client, this._stateReceiver);

  Future<String> _command(String command) async {
    String response = _parse(await _client.command(utf8.encode(command)));

    if (response.startsWith("error")) {
      String errorMessage = response.substring(5).trim();
      print(errorMessage);
      throw (errorMessage.isEmpty) ? TelloError() : TelloError(errorMessage);
    }

    return response;
  }

  void _send(String command) => _client.send(utf8.encode(command));

  Future<String> takeoff() => _command("takeoff");

  Future<String> land() => _command("land");

  Future<String> emergencyShutdown() => _command("emergency");

  Future<String> fly(
    FlyDirection direction,
    int lengthCm,
  ) =>
      _command("${direction.toShortString()} $lengthCm");

  Future<String> rotate(
    int angle,
  ) {
    int absAngle = angle;

    String turnDirection = 'cw';

    if (angle < 0) {
      absAngle = -angle;
      turnDirection = 'c' + turnDirection;
    }

    return _command("$turnDirection $absAngle");
  }

  Future<String> flip(
    FlipDirection direction,
  ) =>
      _command("flip ${direction.toShortString()[0]}");

  // https://github.com/dwalker-uk/TelloEduSwarmSearch/issues/1
  Future<String> flyToPosition({
    int x = 0,
    int y = 0,
    int z = 0,
    int speed = 20,
  }) =>
      _command("go $x $y $z $speed");

  // https://tellopilots.com/threads/how-to-use-curve-x1-y1-z1-x2-y2-z2-speed-command.3134/
  Future<String> cruveToPosition({
    int x1 = 0,
    int y1 = 0,
    int z1 = 0,
    int x2 = 0,
    int y2 = 0,
    int z2 = 0,
    int speed = 20,
  }) =>
      _command("curve $x1 $y1 $z1 $x2 $y2 $z2 $speed");

  Future<String> setSpeed(
    int speedCmPerSec,
  ) =>
      _command("speed $speedCmPerSec");

  void remoteControl(
          {int roll = 0, int pitch = 0, int yaw = 0, int vertical = 0}) =>
      _send("rc $roll $pitch $vertical $yaw");

  Future<String> changeWifi({
    required String name,
    required String password,
  }) =>
      _command("wifi $name $password");

  // https://tellopilots.com/threads/tello-video-web-streaming.455/
  Future<String> startVideo() => _command("streamon");
  Future<String> stopVideo() => _command("streamoff");

  Future<Uint8List?> custom(List<int> command, {bool awaitResponse = true}) {
    if (awaitResponse) return _client.command(command);

    _client.send(command);
    return Future.value(null);
  }

  Stream<TelloState> get state =>
      _stateReceiver.responses.map((Uint8List currentState) {
        RegExp telloStateRegex = RegExp(
            r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;vgx:)(.+)(;vgy:)(.+)(;vgz:)(.+)(;templ:)(.+)(;temph:)(.+)(;tof:)(.+)(;h:)(.+)(;bat:)(.+)(;baro:)(.+)(;time:)(.+)(;agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");

        RegExpMatch matches = telloStateRegex.firstMatch(_parse(currentState))!;

        return TelloState(
          IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
              int.parse("${matches[7]}")),
          IMUVelocity(int.parse("${matches[9]}"), int.parse("${matches[11]}"),
              int.parse("${matches[13]}")),
          IMUAcceleration(double.parse("${matches[29]}"),
              double.parse("${matches[31]}"), double.parse("${matches[33]}")),
          (double.parse("${matches[15]}") + double.parse("${matches[17]}")) / 2,
          int.parse("${matches[19]}"),
          int.parse("${matches[21]}"),
          int.parse("${matches[23]}"),
          double.parse("${matches[25]}"),
          int.parse("${matches[27]}"),
        );
      });

  Future<double> get speed async => double.parse((await _command("speed?")));

  Future<int> get battery async => int.parse((await _command("battery?")));

  Future<int> get flightTime async {
    String flightTimeResponse = (await _command("time?"));

    RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

    return int.parse("${matches[2]}");
  }

  Future<int> get height async {
    String heightResponse = (await _command("height?"));

    RegExp heightRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

    return int.parse("${matches[2]}");
  }

  Future<double> get averageTemprature async {
    String tempratureResponse = (await _command("temp?"));

    RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");
    RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

    return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
  }

  Future<IMUAttitude> get imuAttitude async {
    String imuAttitudeReponse = (await _command("attitude?"));

    RegExp imuAttitudeRegex =
        RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
    RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

    return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
        int.parse("${matches[7]}"));
  }

  Future<double> get barometerReading async =>
      double.parse((await _command("baro?")));

  Future<IMUAcceleration> get imuAcceleration async {
    String imuAccelerationReponse = (await _command("acceleration?"));

    RegExp imuAccelerationRegex =
        RegExp(r"((agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");
    RegExpMatch matches =
        imuAccelerationRegex.firstMatch(imuAccelerationReponse)!;

    return IMUAcceleration(double.parse("${matches[3]}"),
        double.parse("${matches[5]}"), double.parse("${matches[7]}"));
  }

  Future<double> get distanceFromTakeoff async {
    String distanceFromTakeoffResponse = (await _command("tof?"));

    RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
    RegExpMatch matches =
        distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

    return double.parse("${matches[2]}");
  }

  Future<int> get wifiSnr async => int.parse((await _command("wifi?")));

  void disconnect() {
    _client.disconnect();
    _stateReceiver.disconnect();
  }
}

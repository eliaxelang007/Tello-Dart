import 'dart:async';
import 'dart:io';

import 'modules/utilities/enums.dart';
import 'modules/utilities/range.dart';

import 'modules/socket.dart';
import 'modules/logger.dart';

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

    await tello._client.command("command");
    //await tello._stateReceiver.responses.first;

    return tello;
  }

  Tello._(this._client, this._stateReceiver);

  Future<String> takeoff() => _client.command("takeoff");

  Future<String> land() => _client.command("land");

  Future<String> emergencyShutdown() => _client.command("emergency");

  Future<String> fly(
    FlyDirection direction,
    int lengthCm,
  ) {
    return _client.command("${direction.toShortString()} $lengthCm");
  }

  Future<String> rotate(
    int angle,
  ) {
    int absAngle = angle;

    String turnDirection = 'cw';

    if (angle < 0) {
      absAngle = -angle;
      turnDirection = 'c' + turnDirection;
    }

    return _client.command("$turnDirection $absAngle");
  }

  Future<String> flip(
    FlipDirection direction,
  ) =>
      _client.command("flip ${direction.toShortString()[0]}");

  // https://github.com/dwalker-uk/TelloEduSwarmSearch/issues/1
  Future<String> flyToPosition(
    int xPosition,
    int yPosition,
    int zPosition,
    int speedCmPerSec,
  ) {
    return _client
        .command("go $xPosition $yPosition $zPosition $speedCmPerSec");
  }

  // https://tellopilots.com/threads/how-to-use-curve-x1-y1-z1-x2-y2-z2-speed-command.3134/
  Future<String> cruveToPosition(
    int x1Position,
    int y1Position,
    int z1Position,
    int x2Position,
    int y2Position,
    int z2Position,
    int speedCmPerSec,
  ) {
    return _client.command(
        "curve $x1Position $y1Position $z1Position $x2Position $y2Position $z2Position $speedCmPerSec");
  }

  Future<String> setSpeed(
    int speedCmPerSec,
  ) {
    return _client.command("speed $speedCmPerSec");
  }

  void setRemoteControl(int roll, int pitch, int upDown, int yaw) {
    void forceRemoteControlRange(int remoteControl) {}

    forceRemoteControlRange(roll);
    forceRemoteControlRange(pitch);
    forceRemoteControlRange(upDown);
    forceRemoteControlRange(yaw);

    return _client.send("rc $roll $pitch $upDown $yaw");
  }

  Future<String> changeConnectionInfo({
    required String name,
    required String password,
  }) =>
      _client.command("wifi $name $password");

  // https://tellopilots.com/threads/tello-video-web-streaming.455/
  Future<String> startVideo() => _client.command("streamon");
  Future<String> stopVideo() => _client.command("streamoff");

  Future<String?> custom(String command, {bool awaitResponse = true}) {
    if (awaitResponse) return _client.command(command);

    _client.send(command);
    return Future.value(null);
  }

  Stream<TelloState> get state {
    return _stateReceiver.responses.map((String currentState) {
      RegExp telloStateRegex = RegExp(
          r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;vgx:)(.+)(;vgy:)(.+)(;vgz:)(.+)(;templ:)(.+)(;temph:)(.+)(;tof:)(.+)(;h:)(.+)(;bat:)(.+)(;baro:)(.+)(;time:)(.+)(;agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");

      RegExpMatch matches = telloStateRegex.firstMatch(currentState)!;

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
  }

  Future<double> get speed async =>
      double.parse((await _client.command("speed?")));

  Future<int> get battery async =>
      int.parse((await _client.command("battery?")));

  Future<int> get flightTime async {
    String flightTimeResponse = (await _client.command("time?"));

    RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

    Logger.log("Tello Flight Time Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<int> get height async {
    String heightResponse = (await _client.command("height?"));

    RegExp heightRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

    Logger.log("Tello Height Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<double> get averageTemprature async {
    String tempratureResponse = (await _client.command("temp?"));

    RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");
    RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

    Logger.log("Tello Temprature Unit: '${matches[3]}'");

    return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
  }

  Future<IMUAttitude> get imuAttitude async {
    String imuAttitudeReponse = (await _client.command("attitude?"));

    RegExp imuAttitudeRegex =
        RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
    RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

    Logger.log("Tello IMU Attitude Units: Pitch, Roll, Yaw");

    return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
        int.parse("${matches[7]}"));
  }

  Future<double> get barometerReading async =>
      double.parse((await _client.command("baro?")));

  Future<IMUAcceleration> get imuAcceleration async {
    String imuAccelerationReponse = (await _client.command("acceleration?"));

    RegExp imuAccelerationRegex =
        RegExp(r"((agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");
    RegExpMatch matches =
        imuAccelerationRegex.firstMatch(imuAccelerationReponse)!;

    Logger.log(
        "Tello IMU Acceleration Units: X Acceleration, Y Acceleration, Z Acceleration");

    return IMUAcceleration(double.parse("${matches[3]}"),
        double.parse("${matches[5]}"), double.parse("${matches[7]}"));
  }

  Future<double> get distanceFromTakeoff async {
    String distanceFromTakeoffResponse = (await _client.command("tof?"));

    RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
    RegExpMatch matches =
        distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

    Logger.log("Tello Distance Form Takeoff Units: '${matches[3]}'");

    return double.parse("${matches[2]}");
  }

  Future<int> get wifiSnr async {
    return int.parse((await _client.command("wifi?")));
  }

  void disconnect() {
    _client.disconnect();
    _stateReceiver.disconnect();
  }
}

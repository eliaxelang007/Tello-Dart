import 'modules/utilities/enums.dart';

import "modules/tello_socket.dart";
import 'modules/logger.dart';

enum FlyDirection { forward, back, left, right, up, down }
enum FlipDirection { front, back, left, right }

class IMUAttitude {
  final int pitch;
  final int roll;
  final int yaw;

  const IMUAttitude(this.pitch, this.roll, this.yaw);
}

class IMUAcceleration {
  final double xAcceleration;
  final double yAcceleration;
  final double zAcceleration;

  const IMUAcceleration(
      this.xAcceleration, this.yAcceleration, this.zAcceleration);
}

class IMUVelocity {
  final int xVelocity;
  final int yVelocity;
  final int zVelocity;

  const IMUVelocity(this.xVelocity, this.yVelocity, this.zVelocity);
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
      this.averageTemprature,
      this.distanceFromTakeoff,
      this.height,
      this.battery,
      this.barometerReading,
      this.flightTime,
      this.imuAcceleration);
}

class Tello {
  late final Logger _logger;
  late final TelloSocket _client;
  late final TelloSocket _stateReceiver;

  bool logging;

  static Future<Tello> tello({
    bool logging = false,
    Duration responseTimeout = const Duration(seconds: 12),
    String telloIp = "192.168.10.1",
    int telloPort = 8889,
    String clientIp = "0.0.0.0",
    int clientPort = 9000,
    String stateReceiverIp = "0.0.0.0",
    int stateReceiverPort = 8890,
  }) async {
    Tello tello = Tello._(
        logging: logging,
        responseTimeout: responseTimeout,
        telloIp: telloIp,
        telloPort: telloPort,
        clientIp: clientIp,
        clientPort: clientPort,
        stateReceiverIp: stateReceiverIp,
        stateReceiverPort: stateReceiverPort);

    await tello._client.sendCommand("command");

    return tello;
  }

  Tello._({
    this.logging = false,
    Duration responseTimeout = const Duration(seconds: 12),
    String telloIp = "192.168.10.1",
    int telloPort = 8889,
    String clientIp = "0.0.0.0",
    int clientPort = 9000,
    String stateReceiverIp = "0.0.0.0",
    int stateReceiverPort = 8890,
  }) {
    _logger = Logger(logging);
    _client = TelloSocket(_logger,
        responseTimeout: responseTimeout,
        telloIp: telloIp,
        telloPort: telloPort,
        clientIp: clientIp,
        clientPort: clientPort);
    _stateReceiver = TelloSocket(_logger,
        responseTimeout: responseTimeout,
        telloIp: telloIp,
        telloPort: telloPort,
        clientIp: stateReceiverIp,
        clientPort: stateReceiverPort);
  }

  Future<String> takeoff() => _client.sendCommand("takeoff");

  Future<String> land() => _client.sendCommand("land");

  Future<String> emergencyShutdown() => _client.sendCommand("emergency");

  Future<String> fly(FlyDirection direction, int lengthCm) =>
      _client.sendCommand("${direction.toShortString()} $lengthCm");

  Future<String> rotate(int angle) =>
      _client.sendCommand("${(angle < 0) ? 'c' : ''}cw ${angle.abs()}");

  Future<String> rotateClockwise(int angle) => _client.sendCommand("cw $angle");

  Future<String> rotateCounterclockwise(int angle) =>
      _client.sendCommand("ccw $angle");

  Future<String> flip(FlipDirection direction) =>
      _client.sendCommand("flip ${direction.toShortString()[0]}");

  Future<String> flyToPosition(
          int xPosition, int yPosition, int zPosition, int speedCmPerSec) =>
      _client.sendCommand("go $xPosition $yPosition $zPosition $speedCmPerSec");

  Future<String> cruveToPosition(int x1Position, int y1Position, int z1Position,
          int x2Position, int y2Position, int z2Position, int speedCmPerSec) =>
      _client.sendCommand(
          "curve $x1Position $y1Position $z1Position $x2Position $y2Position $z2Position $speedCmPerSec");

  Future<String> setSpeed(int speedCmPerSec) =>
      _client.sendCommand("speed $speedCmPerSec");

  Future<String> setRemoteControl(int roll, int pitch, int upDown, int yaw) =>
      _client.sendCommand("rc $roll $pitch $upDown $yaw");

  Future<String> changeTelloWifiInfo(
          String newTelloWifiName, String newTelloWifiPassword) =>
      _client.sendCommand("wifi $newTelloWifiName $newTelloWifiPassword");

  // https://tellopilots.com/threads/tello-video-web-streaming.455/
  Future<String> startStream() => _client.sendCommand("streamon");

  Future<String> stopStream() => _client.sendCommand("streamoff");

  Future<TelloState> get telloState async {
    String telloStateResponse = await _stateReceiver.receiveData();

    RegExp telloStateRegex = RegExp(
        r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;vgx:)(.+)(;vgy:)(.+)(;vgz:)(.+)(;templ:)(.+)(;temph:)(.+)(;tof:)(.+)(;h:)(.+)(;bat:)(.+)(;baro:)(.+)(;time:)(.+)(;agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");

    RegExpMatch matches = telloStateRegex.firstMatch(telloStateResponse)!;

    return TelloState(
        IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
            int.parse("${matches[7]}")),
        IMUVelocity(int.parse("${matches[9]}"), int.parse("${matches[11]}"),
            int.parse("${matches[13]}")),
        (double.parse("${matches[15]}") + double.parse("${matches[17]}")) / 2,
        int.parse("${matches[19]}"),
        int.parse("${matches[21]}"),
        int.parse("${matches[23]}"),
        double.parse("${matches[25]}"),
        int.parse("${matches[27]}"),
        IMUAcceleration(double.parse("${matches[29]}"),
            double.parse("${matches[31]}"), double.parse("${matches[33]}")));
  }

  Future<double> get speed async =>
      double.parse(await _client.sendCommand("speed?"));

  Future<int> get battery async =>
      int.parse(await _client.sendCommand("battery?"));

  Future<int> get flightTime async {
    String flightTimeResponse = await _client.sendCommand("time?");

    RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

    _logger.logData("Tello Flight Time Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<int> get height async {
    String heightResponse = await _client.sendCommand("height?");

    RegExp heightRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

    _logger.logData("Tello Height Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<double> get averageTemprature async {
    String tempratureResponse = await _client.sendCommand("temp?");

    RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");
    RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

    _logger.logData("Tello Temprature Unit: '${matches[3]}'");

    return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
  }

  Future<IMUAttitude> get imuAttitude async {
    String imuAttitudeReponse = await _client.sendCommand("attitude?");

    RegExp imuAttitudeRegex =
        RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
    RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

    _logger.logData("Tello IMU Attitude Units: Pitch, Roll, Yaw");

    return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
        int.parse("${matches[7]}"));
  }

  Future<double> get barometerReading async =>
      double.parse(await _client.sendCommand("baro?"));

  Future<IMUAcceleration> get imuAcceleration async {
    String imuAccelerationReponse = await _client.sendCommand("acceleration?");

    RegExp imuAccelerationRegex =
        RegExp(r"((agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");
    RegExpMatch matches =
        imuAccelerationRegex.firstMatch(imuAccelerationReponse)!;

    _logger.logData(
        "Tello IMU Acceleration Units: X Acceleration, Y Acceleration, Z Acceleration");

    return IMUAcceleration(double.parse("${matches[3]}"),
        double.parse("${matches[5]}"), double.parse("${matches[7]}"));
  }

  Future<double> get distanceFromTakeoff async {
    String distanceFromTakeoffResponse = await _client.sendCommand("tof?");

    RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
    RegExpMatch matches =
        distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

    _logger.logData("Tello Distance Form Takeoff Units: '${matches[3]}'");

    return double.parse("${matches[2]}");
  }

  Future<int> get wifiSnr async {
    return int.parse(await _client.sendCommand("wifi?"));
  }
}

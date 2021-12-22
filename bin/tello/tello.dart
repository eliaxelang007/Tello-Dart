import 'modules/utilities/enums.dart';
import 'modules/utilities/range.dart';

import "modules/tello_socket.dart";
import 'modules/logger.dart';

void _forceRange(int value, Range range) {
  if (range(value)) return;
  throw FormatException("A value exceeded the limits $range");
}

enum FlyDirection { forward, back, left, right, up, down }
enum FlipDirection { front, back, left, right }

class IMUAttitude {
  final int pitch;
  final int roll;
  final int yaw;

  const IMUAttitude(this.pitch, this.roll, this.yaw);

  @override
  String toString() => "IMUAttitude(pitch: $pitch, roll: $roll, yaw: $yaw)";
}

class IMUAcceleration {
  final double xAcceleration;
  final double yAcceleration;
  final double zAcceleration;

  const IMUAcceleration(
      this.xAcceleration, this.yAcceleration, this.zAcceleration);

  @override
  String toString() =>
      "IMUAcceleration(xAcceleration: $xAcceleration, yAcceleration: $yAcceleration, zAcceleration: $zAcceleration)";
}

class IMUVelocity {
  final int xVelocity;
  final int yVelocity;
  final int zVelocity;

  const IMUVelocity(this.xVelocity, this.yVelocity, this.zVelocity);

  @override
  String toString() =>
      "IMUAcceleration(xVelocity: $xVelocity, yVelocity: $yVelocity, zVelocity: $zVelocity)";
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

  Map<String, dynamic> _toMap() {
    return {
      "imuAttitude": imuAttitude,
      "imuVelocity": imuVelocity,
      "imuAcceleration": imuAcceleration,
      "averageTemprature": averageTemprature,
      "distanceFromTakeoff": distanceFromTakeoff,
      "height": height,
      "battery": battery,
      "barometerReading": barometerReading,
      "flightTime": flightTime,
    };
  }

  @override
  String toString() {
    return "TelloState\n(\n\t${_toMap().entries.map((element) => '${element.key}: ${element.value}').join('\n\t')}\n)";
  }
}

class Tello {
  final TelloSocket _client;
  final TelloSocket _stateReceiver;

  final bool _landOnDisconnect;

  late final int _startFlightTime;

  static Future<Tello> tello({
    bool landOnDisconnect = true,
    Duration responseTimeout = const Duration(seconds: 12),
    String telloIp = "192.168.10.1",
    int telloPort = 8889,
    String clientIp = "0.0.0.0",
    int clientPort = 9000,
    String stateReceiverIp = "0.0.0.0",
    int stateReceiverPort = 8890,
  }) async {
    Tello tello = Tello._(
        landOnDisconnect: landOnDisconnect,
        responseTimeout: responseTimeout,
        telloIp: telloIp,
        telloPort: telloPort,
        clientIp: clientIp,
        clientPort: clientPort,
        stateReceiverIp: stateReceiverIp,
        stateReceiverPort: stateReceiverPort);

    await tello._client.sendCommand("command");
    tello._startFlightTime = await tello.flightTime;

    return tello;
  }

  Tello._({
    bool landOnDisconnect = true,
    Duration responseTimeout = const Duration(seconds: 12),
    String telloIp = "192.168.10.1",
    int telloPort = 8889,
    String clientIp = "0.0.0.0",
    int clientPort = 9000,
    String stateReceiverIp = "0.0.0.0",
    int stateReceiverPort = 8890,
  })  : _landOnDisconnect = landOnDisconnect,
        _client = TelloSocket(
            responseTimeout: responseTimeout,
            telloIp: telloIp,
            telloPort: telloPort,
            clientIp: clientIp,
            clientPort: clientPort),
        _stateReceiver = TelloSocket(
            responseTimeout: responseTimeout,
            telloIp: telloIp,
            telloPort: telloPort,
            clientIp: stateReceiverIp,
            clientPort: stateReceiverPort);

  void _forceFlyingRange(int lengthCm) =>
      _forceRange(lengthCm.abs(), const Range(20, 500));

  void _forceSpeedRange(int speedCmPerSec) =>
      _forceRange(speedCmPerSec, const Range(10, 100));

  Future<String> takeoff() => _client.sendCommand("takeoff");

  Future<String> land() => _client.sendCommand("land");

  Future<String> emergencyShutdown() async {
    String response = await _client.sendCommand("emergency");

    _client.close();

    return response;
  }

  Future<String> fly(
    FlyDirection direction,
    int lengthCm,
  ) {
    _forceFlyingRange(lengthCm);
    return _client.sendCommand("${direction.toShortString()} $lengthCm");
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

    _forceRange(absAngle, const Range(1, 3600));

    return _client.sendCommand("$turnDirection $absAngle");
  }

  Future<String> flip(
    FlipDirection direction,
  ) =>
      _client.sendCommand("flip ${direction.toShortString()[0]}");

  Future<String> flyToPosition(
    int xPosition,
    int yPosition,
    int zPosition,
    int speedCmPerSec,
  ) {
    _forceFlyingRange(xPosition);
    _forceFlyingRange(yPosition);
    _forceFlyingRange(zPosition);
    _forceSpeedRange(speedCmPerSec);

    return _client
        .sendCommand("go $xPosition $yPosition $zPosition $speedCmPerSec");
  }

  Future<String> cruveToPosition(
    int x1Position,
    int y1Position,
    int z1Position,
    int x2Position,
    int y2Position,
    int z2Position,
    int speedCmPerSec,
  ) {
    _forceFlyingRange(x1Position);
    _forceFlyingRange(y1Position);
    _forceFlyingRange(z1Position);
    _forceFlyingRange(x2Position);
    _forceFlyingRange(y2Position);
    _forceFlyingRange(z2Position);
    _forceSpeedRange(speedCmPerSec);

    return _client.sendCommand(
        "curve $x1Position $y1Position $z1Position $x2Position $y2Position $z2Position $speedCmPerSec");
  }

  Future<String> setSpeed(
    int speedCmPerSec,
  ) {
    _forceSpeedRange(speedCmPerSec);
    return _client.sendCommand("speed $speedCmPerSec");
  }

  Future<void> setRemoteControl(int roll, int pitch, int upDown, int yaw) {
    void forceRemoteControlRange(int remoteControl) {
      _forceRange(remoteControl, const Range(-100, 100));
    }

    forceRemoteControlRange(roll);
    forceRemoteControlRange(pitch);
    forceRemoteControlRange(upDown);
    forceRemoteControlRange(yaw);

    return _client.sendData("rc $roll $pitch $upDown $yaw");
  }

  Future<String> changeTelloWifiInfo(
    String newTelloWifiName,
    String newTelloWifiPassword,
  ) =>
      _client.sendCommand("wifi $newTelloWifiName $newTelloWifiPassword");

  // https://tellopilots.com/threads/tello-video-web-streaming.455/
  Future<String> startStream() => _client.sendCommand("streamon");
  Future<String> stopStream() => _client.sendCommand("streamoff");

  Future<Stream<TelloState>> get telloState async {
    return (await _stateReceiver.streamInData()).map((telloStateResponse) {
      RegExp telloStateRegex = RegExp(
          r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;vgx:)(.+)(;vgy:)(.+)(;vgz:)(.+)(;templ:)(.+)(;temph:)(.+)(;tof:)(.+)(;h:)(.+)(;bat:)(.+)(;baro:)(.+)(;time:)(.+)(;agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");

      RegExpMatch matches = telloStateRegex.firstMatch(telloStateResponse)!;

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
      double.parse((await _client.sendCommand("speed?")));

  Future<int> get battery async =>
      int.parse((await _client.sendCommand("battery?")));

  Future<int> get flightTime async {
    String flightTimeResponse = (await _client.sendCommand("time?"));

    RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

    Logger.logData("Tello Flight Time Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<int> get height async {
    String heightResponse = (await _client.sendCommand("height?"));

    RegExp heightRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

    Logger.logData("Tello Height Units: '${matches[3]}'");

    return int.parse("${matches[2]}");
  }

  Future<double> get averageTemprature async {
    String tempratureResponse = (await _client.sendCommand("temp?"));

    RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");
    RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

    Logger.logData("Tello Temprature Unit: '${matches[3]}'");

    return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
  }

  Future<IMUAttitude> get imuAttitude async {
    String imuAttitudeReponse = (await _client.sendCommand("attitude?"));

    RegExp imuAttitudeRegex =
        RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
    RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

    Logger.logData("Tello IMU Attitude Units: Pitch, Roll, Yaw");

    return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
        int.parse("${matches[7]}"));
  }

  Future<double> get barometerReading async =>
      double.parse((await _client.sendCommand("baro?")));

  Future<IMUAcceleration> get imuAcceleration async {
    String imuAccelerationReponse =
        (await _client.sendCommand("acceleration?"));

    RegExp imuAccelerationRegex =
        RegExp(r"((agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");
    RegExpMatch matches =
        imuAccelerationRegex.firstMatch(imuAccelerationReponse)!;

    Logger.logData(
        "Tello IMU Acceleration Units: X Acceleration, Y Acceleration, Z Acceleration");

    return IMUAcceleration(double.parse("${matches[3]}"),
        double.parse("${matches[5]}"), double.parse("${matches[7]}"));
  }

  Future<double> get distanceFromTakeoff async {
    String distanceFromTakeoffResponse = (await _client.sendCommand("tof?"));

    RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
    RegExpMatch matches =
        distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

    Logger.logData("Tello Distance Form Takeoff Units: '${matches[3]}'");

    return double.parse("${matches[2]}");
  }

  Future<int> get wifiSnr async {
    return int.parse((await _client.sendCommand("wifi?")));
  }

  Future<void> disconnect() async {
    try {
      if (_landOnDisconnect && (await flightTime) > _startFlightTime) {
        await land();
      }
    } catch (error) {
      print(
          "We couldn't automatically land your tello because of an error. The error states '$error'");
    } finally {
      await _client.close();
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'modules/utilities/enums.dart';

import 'modules/socket.dart';
import 'modules/error.dart';

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

/// Represents the Tello in your code.
class Tello {
  final TelloSocket _connection;
  final TelloSocket _stateReceiver;

  /// Serves as the constructor for the Tello class, is a static method because constructors can't be aynchronous.
  static Future<Tello> tello({
    Duration timeout = const Duration(seconds: 12),
    Address? telloAddress,
    Address? localAddress,
    Address? stateReceiverAddress,
  }) async {
    stateReceiverAddress = stateReceiverAddress ??
        Address(ip: InternetAddress.anyIPv4, port: 8890);

    List<TelloSocket> sockets = await Future.wait([
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          localAddress: localAddress,
          timeout: timeout),
      TelloSocket.telloSocket(
          telloAddress: telloAddress,
          localAddress: stateReceiverAddress,
          timeout: timeout)
    ]);

    Tello tello = Tello._(sockets[0], sockets[1]);

    await tello._command("command");

    return tello;
  }

  Tello._(this._connection, this._stateReceiver);

  Future<String> _command(String command) async {
    String response = await _connection.command(command);

    if (response.startsWith("error")) {
      String errorMessage = response.substring(5).trim();
      print(errorMessage);
      throw (errorMessage.isEmpty) ? TelloError() : TelloError(errorMessage);
    }

    return response;
  }

  void _send(String command) => _connection.send(command);

  /// Makes the Tello takeoff and then returns the Tello's response.
  Future<String> takeoff() => _command("takeoff");

  /// Makes the Tello land and then returns the Tello's response.
  Future<String> land() => _command("land");

  /// Stops all of the Tello's motors.
  void emergencyShutdown() => _send("emergency");

  /// Makes the Tello fly [lengthCm] in the [direction] you specify.
  Future<String> fly(
    FlyDirection direction,
    int lengthCm,
  ) =>
      _command("${direction.toShortString()} $lengthCm");

  /// Makes the Tello rotate clockwise if [angle] is positive; otherwise, it rotates counterclockwise.
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

  /// Makes the Tello flip in the [direction] you specify.
  Future<String> flip(
    FlipDirection direction,
  ) =>
      _command("flip ${direction.toShortString()[0]}");

  // https://github.com/dwalker-uk/TelloEduSwarmSearch/issues/1
  /// Makes the Tello fly to the ([x], [y], [z]) coordinates relative to its current position.
  Future<String> flyToPosition({
    int x = 0,
    int y = 0,
    int z = 0,
    int speed = 20,
  }) =>
      _command("go $x $y $z $speed");

  // https://tellopilots.com/threads/how-to-use-curve-x1-y1-z1-x2-y2-z2-speed-command.3134/
  /// Makes the Tello move in a curve that passes through the ([x1], [y1], [z1]) and ([x2], [y2], [z2]) coordinates that you specify.
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

  /// Sets the Tello's speed to [speedCmPerSec]
  Future<String> setSpeed(
    int speedCmPerSec,
  ) =>
      _command("speed $speedCmPerSec");

  /// Sets the Tello's remote control to ([roll], [pitch], [yaw], [vertical])
  void remoteControl(
          {int roll = 0, int pitch = 0, int yaw = 0, int vertical = 0}) =>
      _send("rc $roll $pitch $vertical $yaw");

  /// Changes the Tello's wifi name and password to the [name] and [password] you specify.
  Future<String> changeWifi({
    required String name,
    required String password,
  }) =>
      _command("wifi $name $password");

  // https://tellopilots.com/threads/tello-video-web-streaming.455/
  /// Starts the Tello's video stream.
  ///
  /// By default, the Tello streams its video data on port 11111.
  ///
  /// You can get a live feed of the stream with the terminal command:
  /// ```bash
  /// ffmpeg -i udp://0.0.0.0:11111 -f sdl "Tello Video Stream"
  /// ```
  Future<String> startVideo() => _command("streamon");

  /// Stops the Tello's video stream.
  Future<String> stopVideo() => _command("streamoff");

  /// A stream of [TelloState] from the drone.
  Stream<TelloState> get state =>
      _stateReceiver.responses.map((String currentState) {
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

  /// The Tello's speed, persumably in centimeters per seconds.
  Future<double> get speed async => double.parse((await _command("speed?")));

  /// The Tello's battery percentage
  Future<int> get battery async => int.parse((await _command("battery?")));

  /// The Tello's flight time, presumably in seconds.
  Future<int> get flightTime async {
    String flightTimeResponse = (await _command("time?"));

    RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

    return int.parse("${matches[2]}");
  }

  /// The Tello's height from the ground, presumably in centimeters.
  Future<int> get height async {
    String heightResponse = (await _command("height?"));

    RegExp heightRegex = RegExp(r"((\d+)(\w+))");
    RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

    return int.parse("${matches[2]}");
  }

  /// The Tello's average temprature, presumably in celsius.
  Future<double> get averageTemprature async {
    String tempratureResponse = (await _command("temp?"));

    RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");
    RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

    return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
  }

  /// The Tello's pitch, roll, and yaw.
  Future<IMUAttitude> get imuAttitude async {
    String imuAttitudeReponse = (await _command("attitude?"));

    RegExp imuAttitudeRegex =
        RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
    RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

    return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"),
        int.parse("${matches[7]}"));
  }

  /// The Tello's barometer reading.
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

  /// The Tello's distance from its takeoff point, presumably in cm.
  Future<double> get distanceFromTakeoff async {
    String distanceFromTakeoffResponse = (await _command("tof?"));

    RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
    RegExpMatch matches =
        distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

    return double.parse("${matches[2]}");
  }

  /// The Tello's wifi strength to your local machine, seems to max out at 90%.
  Future<int> get wifiSnr async => int.parse((await _command("wifi?")));

  /// Closes sockets that connect to the Tello and cancels any lingering listeners to the Tello's state.
  void disconnect() {
    _connection.disconnect();
    _stateReceiver.disconnect();
  }
}

import 'dart:io';

import "modules/tello_socket.dart";
import "modules/tello_logger.dart";

class IMUAttitude 
{
    final int pitch;
    final int roll;
    final int yaw;

    const IMUAttitude(this.pitch, this.roll, this.yaw);
}

class IMUAcceleration 
{
    final double xAcceleration;
    final double yAcceleration;
    final double zAcceleration;

    const IMUAcceleration(this.xAcceleration, this.yAcceleration, this.zAcceleration);
}

class IMUVelocity 
{
    final int xVelocity;
    final int yVelocity;
    final int zVelocity;

    const IMUVelocity(this.xVelocity, this.yVelocity, this.zVelocity);
}

class TelloState 
{
    final IMUAttitude imuAttitude;
    final IMUVelocity imuVelocity;
    final double averageTemprature;
    final int distanceFromTakeoff;
    final int height;
    final int battery;
    final double barometerReading;
    final int flightTime;
    final IMUAcceleration imuAcceleration;

    const TelloState(this.imuAttitude, this.imuVelocity, this.averageTemprature, this.distanceFromTakeoff, this.height, this.battery, this.barometerReading, this.flightTime, this.imuAcceleration);
}


class Tello 
{ 
    late final TelloLogger _telloLogger;
    late final TelloSocket _telloClient;
    late final TelloSocket _telloStateReceiver;

    bool telloLogging;

    static Future<Tello> tello(     [bool telloLogging = false, final int telloResponseTimeoutSecs = 12,
     final String telloIp = "192.168.10.1", 
     final int telloPort = 8889,
     final String telloClientIp = "0.0.0.0", 
     final int telloClientPort = 9000,
     final String telloStateReceiverIp = "0.0.0.0", 
     final int telloStateReceiverPort = 8890]) async {
      Tello tello = Tello._(telloLogging, telloResponseTimeoutSecs, telloIp, telloPort, telloClientIp, telloClientPort, telloStateReceiverIp, telloStateReceiverPort);

      await tello._telloClient.sendCommand("command");

      return tello;
    }

    Tello._
    (
     [
       this.telloLogging = false,
     final int telloResponseTimeoutSecs = 12,
     final String telloIp = "192.168.10.1", 
     final int telloPort = 8889,
     final String telloClientIp = "0.0.0.0", 
     final int telloClientPort = 9000,
     final String telloStateReceiverIp = "0.0.0.0", 
     final int telloStateReceiverPort = 8890,
     ]
    ) {
      _telloLogger = TelloLogger(telloLogging);
      _telloClient = TelloSocket(_telloLogger, telloResponseTimeoutSecs, telloIp, telloPort, telloClientIp, telloClientPort);
      _telloStateReceiver = TelloSocket(_telloLogger, telloResponseTimeoutSecs, telloIp, telloPort, telloStateReceiverIp, telloStateReceiverPort);
    }

    Future<String> takeoff() async    {
            return  await _telloClient.sendCommand("takeoff");
    }

    Future<String> land() async    {
            return await _telloClient.sendCommand("land");
    }

    Future<String> emergencyShutdown() async    {
            return await _telloClient.sendCommand("emergency");
    }

    Future<String> flyForward(final int forwardCm) async
    {
            return await _telloClient.sendCommand("forward $forwardCm");
    }

    Future<String> flyBackward(final int backwardCm) async
    {
            return await _telloClient.sendCommand("back $backwardCm");
    }

    Future<String> flyUp(final int upCm) async
    {
            return await _telloClient.sendCommand("up $upCm");
    }

    Future<String> flyDown(final int downCm) async
    {
            return await _telloClient.sendCommand("down $downCm");
    }

    Future<String> flyLeft(final int leftCm) async
    {
            return await _telloClient.sendCommand("left $leftCm");
    }

    Future<String> flyRight(final int rightCm) async
    {
            return await _telloClient.sendCommand("right $rightCm");
    }

    Future<String> rotateClockwise(final int angle) async
    {
            return await _telloClient.sendCommand("cw $angle");
    }

    Future<String> rotateCounterclockwise(final int angle) async
    {
            return await _telloClient.sendCommand("ccw $angle");
    }

    Future<String> frontFlip() async    {
            return await _telloClient.sendCommand("flip f");
    }

    Future<String> backFlip() async    {
            return await _telloClient.sendCommand("flip b");
    }

    Future<String> leftFlip() async    {
            return await _telloClient.sendCommand("flip l");
    }

    Future<String> rightFlip() async    {
            return await _telloClient.sendCommand("flip r");
    }

    Future<String> flyToPosition(final int xPosition, final int yPosition, final int zPosition, final int speedCmPerSec) async
    {
            return await _telloClient.sendCommand("go $xPosition $yPosition $zPosition $speedCmPerSec");
    }

  Future<String> cruveToPosition(final int x1Position, final int y1Position, final int z1Position, int x2Position, final int y2Position, final int z2Position, final int speedCmPerSec) async
    {
            return await _telloClient.sendCommand("curve $x1Position $y1Position $z1Position $x2Position $y2Position $z2Position $speedCmPerSec");
    }

    Future<String> setSpeed(final int speedCmPerSec) async
    {
            return await _telloClient.sendCommand("speed $speedCmPerSec");
    }

    Future<String> setRemoteControl(final int roll, final int pitch, final int upDown, final int yaw) async
    {
            return await _telloClient.sendCommand("rc $roll $pitch $upDown $yaw");
    }

    Future<String> changeTelloWifiInfo(final String newTelloWifiName, final String newTelloWifiPassword) async
    {
            return await _telloClient.sendCommand("wifi $newTelloWifiName $newTelloWifiPassword");
    }

    Future<TelloState> getTelloState() async    {
            String telloStateResponse = await _telloStateReceiver.receiveData();

            final RegExp telloStateRegex = RegExp
            (
              r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;vgx:)(.+)(;vgy:)(.+)(;vgz:)(.+)(;templ:)(.+)(;temph:)(.+)(;tof:)(.+)(;h:)(.+)(;bat:)(.+)(;baro:)(.+)(;time:)(.+)(;agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))"
            );

            RegExpMatch matches = telloStateRegex.firstMatch(telloStateResponse)!;

            return TelloState
            (
              IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"), int.parse("${matches[7]}")), 
              IMUVelocity(int.parse("${matches[9]}"), int.parse("${matches[11]}"), int.parse("${matches[13]}")), 
              (double.parse("${matches[15]}") + double.parse("${matches[17]}")) / 2,
              int.parse("${matches[19]}"), 
              int.parse("${matches[21]}"), 
              int.parse("${matches[23]}"), 
              double.parse("${matches[25]}"), 
              int.parse("${matches[27]}"), 
              IMUAcceleration(double.parse("${matches[29]}"), double.parse("${matches[31]}"), double.parse("${matches[33]}"))
            );

    }

    Future<double> getSpeed() async
    {
            return double.parse(await _telloClient.sendCommand("speed?"));
    }

    Future<int> getBattery() async
    {
            return int.parse(await _telloClient.sendCommand("battery?"));
    }

    Future<int> getFlightTime() async
    {
            String flightTimeResponse = await _telloClient.sendCommand("time?");

            final RegExp flightTimeRegex = RegExp(r"((\d+)(\w+))");
            RegExpMatch matches = flightTimeRegex.firstMatch(flightTimeResponse)!;

            _telloLogger.logData("Tello Flight Time Units: '${matches[3]}'");

            return int.parse("${matches[2]}");
    }

    Future<int> getHeight() async
    {
            String heightResponse = await _telloClient.sendCommand("height?");

            final RegExp heightRegex = RegExp(r"((\d+)(\w+))");

            RegExpMatch matches = heightRegex.firstMatch(heightResponse)!;

            _telloLogger.logData("Tello Height Units: '${matches[3]}'");

            return int.parse("${matches[2]}");
    }

    Future<double> getAverageTemprature() async
    {
            String tempratureResponse = await _telloClient.sendCommand("temp?");

            final RegExp tempratureRegex = RegExp(r"((\d+)(~)(\d+)(\w+))");

            RegExpMatch matches = tempratureRegex.firstMatch(tempratureResponse)!;

            _telloLogger.logData("Tello Temprature Unit: '${matches[3]}'");

            return (double.parse("${matches[2]}") + double.parse("${matches[4]}")) / 2;
    }

    Future<IMUAttitude> getImuAttitude() async
    {
            String imuAttitudeReponse = await _telloClient.sendCommand("attitude?");

            final RegExp imuAttitudeRegex = RegExp(r"((pitch:)(.+)(;roll:)(.+)(;yaw:)(.+)(;))");
            RegExpMatch matches = imuAttitudeRegex.firstMatch(imuAttitudeReponse)!;

            _telloLogger.logData("Tello IMU Attitude Units: Pitch, Roll, Yaw");

            return IMUAttitude(int.parse("${matches[3]}"), int.parse("${matches[5]}"), int.parse("${matches[7]}"));
    }

    Future<double> getBarometerReading() async    {
            return double.parse(await _telloClient.sendCommand("baro?"));
    }

    Future<IMUAcceleration> getImuAcceleration() async    {
            String imuAccelerationReponse = await _telloClient.sendCommand("acceleration?");

            final RegExp imuAccelerationRegex = RegExp(r"((agx:)(.+)(;agy:)(.+)(;agz:)(.+)(;))");
            RegExpMatch matches = imuAccelerationRegex.firstMatch(imuAccelerationReponse)!;

            _telloLogger.logData("Tello IMU Acceleration Units: X Acceleration, Y Acceleration, Z Acceleration");

            return IMUAcceleration(double.parse("${matches[3]}"), double.parse("${matches[5]}"), double.parse("${matches[7]}"));
    }

    Future<double> getDistanceFromTakeoff() async    {
            String distanceFromTakeoffResponse = await _telloClient.sendCommand("tof?");

            final RegExp distanceFromTakeoffRegex = RegExp(r"((\d+|.)(\w+))");
            RegExpMatch matches = distanceFromTakeoffRegex.firstMatch(distanceFromTakeoffResponse)!;

            _telloLogger.logData("Tello Distance Form Takeoff Units: '${matches[3]}'");

            return double.parse("${matches[2]}");
    }

    Future<int> getWifiSnr() async    {
            return int.parse(await _telloClient.sendCommand("wifi?"));
    }
}
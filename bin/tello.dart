import 'dart:async';

import 'tello/modules/logger.dart';
import 'tello/tello.dart';

void main() async {
  /* Initializing */
  Logger.shouldLog = true;
  Tello tello = await Tello.tello();

  /* Flying Around */
  await tello.takeoff();

  await tello.rotate(180);
  await tello.rotate(-180);
  await tello.rotate(180);
  await tello.flip(FlipDirection.back);
  await tello.flyToPosition(20, 20, -100, 30);
  await tello.cruveToPosition(20, 20, 100, 20, 50, -100, 30);
  await tello.setSpeed(10);
  await tello.setRemoteControl(0, 30, 0, 0);
  await tello.setRemoteControl(0, 0, 0, 0);

  /* Streaming In Drone Data */
  StreamSubscription telloStateListener =
      (await tello.telloState).listen((e) => print(e));

  /* Getting Drone Data */
  print({
    "speed": await tello.speed,
    "battery": await tello.battery,
    "flightTime": await tello.flightTime,
    "height": await tello.height,
    "averageTemprature": await tello.averageTemprature,
    "barometerReading": await tello.barometerReading,
    "distanceFromTakeoff": await tello.distanceFromTakeoff,
    "wifiSnr": await tello.wifiSnr,
    "imuAcceleration": await tello.imuAcceleration
  });

  /* Flying Around */
  telloStateListener.cancel();
  await tello
      .disconnect(); // Automatically lands the tello if it hasn't landed yet.
  // tello.emergencyShutdown();
}

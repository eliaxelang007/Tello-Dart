import 'dart:async';

import 'tello/modules/logger.dart';
import 'tello/tello.dart';

void main() async {
  Tello? tello;

  try {
    /* Initializing */
    Logger.shouldLog = false;

    tello = await Tello.tello();

    //tello.changeConnectionInfo(name: "TELLO_DART", password: "tello1234");

    /* Flying Around */
    await tello.takeoff();
    await tello.fly(FlyDirection.up, 90);

    await tello.rotate(180);
    await tello.rotate(-180);
    await tello.rotate(180);
    await tello.rotate(-180);

    await tello.flip(FlipDirection.front);

    await tello.flyToPosition(75, 75, 0, 30);
    await tello.cruveToPosition(70, 70, 0, 140, 0, 0, 30);
    await tello.setSpeed(10);

    tello.setRemoteControl(0, 30, 0, 0);
    await Future.delayed(const Duration(seconds: 1));
    tello.setRemoteControl(0, 0, 0, 0);

    /* Listening To Drone Data */
    StreamSubscription<TelloState> stateListener =
        tello.state.listen((TelloState state) {
      print(state);
    });

    await Future.delayed(const Duration(seconds: 2));
    stateListener.cancel();

    /* Getting Drone Data Values */
    List<dynamic> telloState = await Future.wait([
      tello.speed,
      tello.battery,
      tello.flightTime,
      tello.height,
      tello.averageTemprature,
      tello.imuAttitude,
      tello.barometerReading,
      tello.distanceFromTakeoff,
      tello.wifiSnr,
      tello.imuAcceleration
    ]);

    const List<String> stateValueNames = [
      "speed",
      "battery",
      "flightTime",
      "height",
      "averageTemprature",
      "imuAttitude",
      "barometerReading",
      "distanceFromTakeoff",
      "wifiSnr",
      "imuAcceleration"
    ];

    for (int i = 0; i < telloState.length; i++) {
      print("${stateValueNames[i]}: ${telloState[i]}");
    }

    /* Landing */
    await tello.land();
    //tello.emergencyShutdown();
  } finally {
    /* Cleanup & Disconnection */

    tello
        ?.disconnect(); // IMPORTANT: Must be called to properly dispose of the sockets that connect to the tello.
  }
}

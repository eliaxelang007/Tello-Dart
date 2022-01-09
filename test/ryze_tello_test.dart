import 'dart:async';

import 'package:test/test.dart';

import 'package:ryze_tello/ryze_tello.dart';

void main() {
  late final Tello tello;

  setUpAll(() async {
    print(
        "[Warning] Make sure you're connected to your tello's network before running this test.");
    tello = await Tello.tello();
  });

  group("Flying Around", () {
    test("takeoff()", () async {
      await tello.takeoff();
    });

    test("fly()", () async {
      await tello.fly(FlyDirection.up, 90);
    });

    test("rotate()", () async {
      await tello.rotate(180);
      await tello.rotate(-180);
      await tello.rotate(180);
      await tello.rotate(-180);
    });

    test("flip()", () async {
      await Future.delayed(const Duration(seconds: 1));

      await tello.flip(FlipDirection.front);
    });

    test("flyToPosition()", () async {
      await tello.flyToPosition(x: -102, y: 0, z: 0, speed: 30);
    });

    test("cruveToPosition()", () async {
      await tello.cruveToPosition(x1: 51, z1: 51, x2: 102);
    });

    test("setSpeed()", () async {
      await tello.setSpeed(10);
    });

    test("remoteControl()", () async {
      tello.remoteControl(pitch: 30);
      await Future.delayed(const Duration(seconds: 1));
      tello.remoteControl();
    });
  });

  group("Listening To Drone Data", () {
    test("tello.state.listen()", () async {
      StreamSubscription<TelloState> stateListener =
          tello.state.listen((TelloState state) {
        print(state);
      });

      await Future.delayed(const Duration(seconds: 2));
      stateListener.cancel();
    });
  });

  test("Receiving Drone Data", () async {
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
  });

  tearDownAll(() {
    tello.land();
    tello.disconnect();
  });
}

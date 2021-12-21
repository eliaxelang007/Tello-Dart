import 'tello/tello.dart';

void main() async {
  Tello tello = await Tello.tello(logging: true);

  await tello.battery;

  await tello.takeoff();
  await tello.fly(FlyDirection.forward, 100);

  await tello.flightTime;

  await tello.land();
}

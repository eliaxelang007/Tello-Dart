import 'tello/tello.dart';

void main() async {
  Tello tello = await Tello.tello(logging: true);

  await tello.startStream();

  for (int i = 0; i < 10; i++) {
    await tello.battery;
    await Future.delayed(Duration(seconds: 6));
  }

  await tello.stopStream();
}

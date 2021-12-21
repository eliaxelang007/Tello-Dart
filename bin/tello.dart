import 'tello/tello.dart';

void main() async
{
  Tello tello = await Tello.tello(true);

  print(await tello.getBattery());
}
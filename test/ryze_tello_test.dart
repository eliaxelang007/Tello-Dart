import 'dart:typed_data';

import 'package:ryze_tello/ryze_tello.dart';
import 'package:ryze_tello/src/modules/packet.dart';
import 'package:test/test.dart';

void main() async {
  group("class $Packet", () {
    test(".buffer", () {
      final packet =
          Packet(Command.takeoff, sequence: 1, packetType: PacketType.command)
              .buffer;

      // https://github.com/Kragrathea/TelloLib/blob/master/TelloLib/Tello.cs
      final sample =
          Uint8List.fromList([204, 88, 0, 124, 104, 84, 0, 1, 0, 106, 144]);

      for (int i = 0; i < packet.length; i++) {
        expect(packet[i], equals(sample[i]));
      }
    });
  });

  group("class $Tello", () {
    print(
        "[Warning] Make sure you're connected to your tello's network before running this test.");

    late final Tello tello;

    setUpAll(() async {
      tello = await Tello.tello();
    });

    test(".takeoff(...)", () async {
      await tello.takeoff();
    });

    test(".land(...)", () async {
      await Future.delayed(const Duration(seconds: 5));
      await tello.land();
    });
  });

  // late final Tello tello;

  // setUpAll(() async {
  //   print(
  //       "[Warning] Make sure you're connected to your tello's network before running this test.");
  //   tello = await Tello.tello();
  // });

  // group("Successfully connected!", () {
  //   print("Yay!");
  // });

  // tearDownAll(() {
  //   tello.disconnect();
  // });
}

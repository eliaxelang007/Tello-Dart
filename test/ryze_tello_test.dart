import 'dart:typed_data';

import 'package:ryze_tello/src/modules/packet.dart';
import 'package:test/test.dart';

import 'package:ryze_tello/ryze_tello.dart';

bool isBitSet(int number, int position) {
  return ((number >> position) & 1) == 1;
}

void main() {
  // test("Packet Testing", () {
  //   Packet packet = Packet(Command.takeoff);

  //   Uint8List sample = Uint8List.fromList(
  //       [0xcc, 0x58, 0x00, 0x7c, 0x68, 0x54, 0x00, 0x00, 0x00, 0xc2, 0x16]);

  //   print(sample);
  //   print(packet.buffer);
  // });

  setUpAll(() async {
    final Tello tello = await Tello.tello();
    try {
      print(
          "[Warning] Make sure you're connected to your tello's network before running this test.");

      tello.takeoff();

      print("Waiting...");
      await Future.delayed(const Duration(seconds: 10));
      print("Done");

      tello.land();
    } finally {
      tello.disconnect();
    }
  });
}

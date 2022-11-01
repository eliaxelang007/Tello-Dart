import 'dart:typed_data';

import 'package:ryze_tello/ryze_tello.dart';
import 'package:ryze_tello/src/modules/packet.dart';
import 'package:test/test.dart';

void main() async {
  group("class $Packet", () {
    var commandSequence = 1;

    test("Command.takeoff", () {
      final packet =
          Packet(Command.takeoff, sequence: commandSequence++).buffer;

      //
      final sample =
          Uint8List.fromList([204, 88, 0, 124, 104, 84, 0, 1, 0, 106, 144]);

      for (int i = 0; i < packet.length; i++) {
        expect(packet[i], equals(sample[i]));
      }
    });

    test("Command.land", () {
      final packet =
          Packet(Command.land, sequence: commandSequence++, payload: [0x00])
              .buffer;

      final sample =
          Uint8List.fromList([204, 96, 0, 39, 104, 85, 0, 2, 0, 0, 198, 91]);

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
      await Future.delayed(const Duration(seconds: 5));
    });

    test(".land(...)", () async {
      await tello.land();
    });
  });
}

/* -- References -- */
// https://github.com/Kragrathea/TelloLib/blob/master/TelloLib/Tello.cs
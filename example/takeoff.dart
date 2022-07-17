import 'dart:async';

import 'package:ryze_tello/ryze_tello.dart';

void main() async {
  late final Tello tello;

  try {
    /* Initializing */
    tello = await Tello.tello();

    await tello.takeoff();

    await Future.delayed(const Duration(seconds: 5));

    await tello.land();
  } catch (error, stacktrace) {
    print("Error: $error");
    print("Stack Trace: $stacktrace");
  } finally {
    /* Cleanup & Disconnection */
    tello
        .disconnect(); // IMPORTANT: Must be called to properly dispose of the sockets that connect to the tello.
  }
}

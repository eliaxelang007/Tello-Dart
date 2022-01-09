A library that provides a high level way for you to interact with your Tello.

## Getting started

* Make sure that your Tello has a good amount of battery
* Turn on your Tello
* Connect to your Tello's wifi
* Run the example script and watch your Tello fly!

## Usage

Here's some sample code that shows how you can make a Tello takeoff,
hover in the air for 5 seconds, and then land. 

An important thing to note here is that tello.disconnect() must be called 
to properly dispose of the sockets that connect to the tello.

```dart
import 'package:ryze_tello/ryze_tello.dart';

void main() async {
  late final Tello tello;

  try {
    /* Initializing */
    tello = await Tello.tello();

    /* Flying Around */
    await tello.takeoff();

    await Future.delayed(const Duration(seconds: 5));

    await tello.land();
  } finally {
    /* Cleanup & Disconnection */
    tello
        .disconnect(); 
  }
}
```

## Additional information

You may find these links helpful for understanding the underlying SDK 
that serves as the base for this package.

* https://dl-cdn.ryzerobotics.com/downloads/Tello/Tello%20SDK%202.0%20User%20Guide.pdf
* https://dl-cdn.ryzerobotics.com/downloads/tello/20180910/Tello%20SDK%20Documentation%20EN_1.3.pdf
* https://tellopilots.com/wiki/index/
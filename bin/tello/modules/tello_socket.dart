import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger.dart';

class _Address {
  InternetAddress ip;
  int port;

  _Address(this.ip, this.port);

  @override
  String toString() {
    return "($ip, $port)";
  }
}

class TelloSocket {
  final Logger _telloLogger;

  final Future<RawDatagramSocket> _client;
  late final Future<Stream<Datagram>> _incommingStream;
  final _Address _telloAddress;

  TelloSocket(Logger telloLogger,
      {Duration responseTimeout = const Duration(seconds: 12),
      String telloIp = "192.168.10.1",
      int telloPort = 8889,
      String clientIp = "0.0.0.0",
      int clientPort = 9000})
      : _telloLogger = telloLogger,
        _client = RawDatagramSocket.bind(InternetAddress(clientIp), clientPort),
        _telloAddress = _Address(InternetAddress(telloIp), telloPort) {
    _incommingStream = _client.then((client) => client
        .asBroadcastStream()
        .timeout(responseTimeout)
        .where((event) => event == RawSocketEvent.read)
        .map((event) => client.receive())
        .where((event) => event != null)
        .map((event) => event!));
  }

  Future<String> sendCommand(final String toSend) async {
    await sendData(toSend);
    return receiveData();
  }

  Future<void> sendData(String stringData) async {
    InternetAddress telloAddress = _telloAddress.ip;
    int telloPort = _telloAddress.port;

    int sendResult =
        (await _client).send(utf8.encode(stringData), telloAddress, telloPort);

    if (sendResult <= -1) {
      throw SocketException("We couldn't send '$stringData' to your Tello.",
          address: telloAddress, port: telloPort);
    }

    _telloLogger.logData("Sent '$stringData' to '$_telloAddress'");
  }

  Future<String> receiveData() async {
    Datagram receivedData = (await (await _incommingStream).first);

    InternetAddress receivedDataAddress = receivedData.address;

    if (receivedDataAddress != _telloAddress.ip) {
      throw SocketException("Unknown connection from ip $receivedDataAddress");
    }

    String data = utf8.decode(receivedData.data);

    _telloLogger.logData("Received '$data' from $_telloAddress");

    return data.trim();
  }
}

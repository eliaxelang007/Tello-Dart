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
  final Future<RawDatagramSocket> _client;
  final _Address _telloAddress;

  late final Future<Stream<String>> _incommingStream;

  TelloSocket(
      {Duration responseTimeout = const Duration(seconds: 12),
      String telloIp = "192.168.10.1",
      int telloPort = 8889,
      String clientIp = "0.0.0.0",
      int clientPort = 9000})
      : _client = RawDatagramSocket.bind(InternetAddress(clientIp), clientPort),
        _telloAddress = _Address(InternetAddress(telloIp), telloPort) {
    _incommingStream = _client.then((client) => client
            .asBroadcastStream()
            .timeout(responseTimeout)
            .where((event) => event == RawSocketEvent.read)
            .map((event) => client.receive())
            .where((event) => event != null)
            .map((receivedData) {
          receivedData!;
          InternetAddress receivedDataAddress = receivedData.address;

          if (receivedDataAddress != _telloAddress.ip) {
            throw SocketException(
                "Unknown connection from ip $receivedDataAddress");
          }

          String data = utf8.decode(receivedData.data);

          Logger.logData("Received '$data'");

          return data;
        }));
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

    Logger.logData("Sent '$stringData'");
  }

  Future<void> close() async {
    (await _client).close();
  }

  Future<Stream<String>> streamInData() => _incommingStream;

  Future<String> receiveData() async {
    return (await (await _incommingStream).first);
  }
}

import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'cleaner.dart';
import 'error.dart';
import 'logger.dart';

class Address {
  final InternetAddress ip;
  final int port;

  const Address({required this.ip, required this.port});

  @override
  String toString() => "$Address($ip, $port)";
}

class TelloSocket {
  final RawDatagramSocket _socket;
  late final Stream<String> _responses;

  final Address _telloAddress;

  final Queue<Completer<String>> _responseQueue = Queue<Completer<String>>();

  final Cleaner<StreamSubscription<String>> _subscriptionCleaner =
      Cleaner<StreamSubscription<String>>(
          cleaner: (StreamSubscription<String> subscription) {
    subscription.cancel();
  });

  static Future<TelloSocket> telloSocket(
      {Duration timeout = const Duration(seconds: 12),
      Address? telloAddress,
      Address? clientAddress}) async {
    final Address _clientAddress =
        clientAddress ?? Address(ip: InternetAddress.anyIPv4, port: 9000);

    return TelloSocket._(
        await RawDatagramSocket.bind(_clientAddress.ip, _clientAddress.port),
        telloAddress ??
            Address(ip: InternetAddress("192.168.10.1"), port: 8889),
        timeout: timeout);
  }

  TelloSocket._(this._socket, this._telloAddress, {Duration? timeout}) {
    _responses = ((timeout != null) ? _socket.timeout(timeout) : _socket)
        .where((RawSocketEvent event) => event == RawSocketEvent.read)
        .map((RawSocketEvent event) => _socket.receive())
        .where((Datagram? datagram) => datagram != null)
        .map((Datagram? receivedData) {
      receivedData!;
      InternetAddress receivedDataAddress = receivedData.address;

      if (receivedDataAddress != _telloAddress.ip) {
        throw SocketException(
            "Unknown connection from ip $receivedDataAddress");
      }

      String data = utf8.decode(receivedData.data);

      Logger.log("Received '$data'");

      data = data.trim();

      return data;
    }).asBroadcastStream(
            onListen: _subscriptionCleaner.add,
            onCancel: _subscriptionCleaner.remove);

    _responses.listen((String response) {
      if (_responseQueue.isEmpty) return;

      _responseQueue.first.complete(response);
      _responseQueue.removeFirst();
    });
  }

  Future<String> command(String data) {
    Future<String> response = receive();

    send(data);

    return response;
  }

  void send(String data) {
    Address destination = _telloAddress;

    int bufferSize =
        _socket.send(utf8.encode(data), destination.ip, destination.port);

    if (bufferSize != data.length) {
      throw SocketException("We were unable to send '$data' to '$destination'.",
          address: destination.ip, port: destination.port);
    }

    Logger.log("Sent '$data");
  }

  Future<String> receive() async {
    Completer<String> responseWaiter = Completer<String>();

    _responseQueue.add(responseWaiter);

    String response = await responseWaiter.future;

    if (response.startsWith("error")) {
      String errorMessage = response.substring(5).trim();
      print(errorMessage);
      throw (errorMessage.isEmpty) ? TelloError() : TelloError(errorMessage);
    }

    return response;
  }

  Stream<String> get responses => _responses;

  void disconnect() {
    _subscriptionCleaner.cleanup();
    _socket.close();
  }
}

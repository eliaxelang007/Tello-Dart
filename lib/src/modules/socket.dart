import 'dart:typed_data';
import 'dart:collection';
import 'dart:async';
import 'dart:io';

import 'utilities/cleaner.dart';

class Address {
  final InternetAddress ip;
  final int port;

  const Address({required this.ip, required this.port});

  @override
  String toString() => "$Address($ip, $port)";
}

class TelloSocket {
  final RawDatagramSocket _socket;
  late final Stream<Uint8List> _responses;

  final Address _telloAddress;

  final Queue<Completer<Uint8List>> _responseQueue =
      Queue<Completer<Uint8List>>();

  final Cleaner<StreamSubscription<Uint8List>> _subscriptionCleaner =
      Cleaner<StreamSubscription<Uint8List>>(
          cleaner: (StreamSubscription<Uint8List> subscription) {
    subscription.cancel();
  });

  static Future<TelloSocket> telloSocket(
      {Duration timeout = const Duration(seconds: 12),
      Address? telloAddress,
      Address? localAddress}) async {
    final Address _localAddress =
        localAddress ?? Address(ip: InternetAddress.anyIPv4, port: 9000);

    return TelloSocket._(
        await RawDatagramSocket.bind(_localAddress.ip, _localAddress.port),
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

      return receivedData.data;
    }).asBroadcastStream(
            onListen: _subscriptionCleaner.add,
            onCancel: _subscriptionCleaner.remove);

    _responses.listen((Uint8List response) {
      if (_responseQueue.isEmpty) return;

      _responseQueue.removeFirst().complete(response);
    });
  }

  Future<Uint8List> command(Uint8List data) {
    Future<Uint8List> response = receive();

    send(data);

    return response;
  }

  void send(Uint8List data) {
    Address destination = _telloAddress;

    int bufferSize = _socket.send(data, destination.ip, destination.port);

    if (bufferSize != data.length) {
      throw SocketException("Unable to send '$data' to '$destination'.",
          address: destination.ip, port: destination.port);
    }
  }

  Future<Uint8List> receive() {
    Completer<Uint8List> responseWaiter = Completer<Uint8List>();

    _responseQueue.add(responseWaiter);

    return responseWaiter.future;
  }

  Stream<Uint8List> get responses => _responses;

  void disconnect() {
    _subscriptionCleaner.cleanup();
    _socket.close();
  }
}

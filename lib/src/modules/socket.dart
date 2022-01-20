import 'dart:collection';
import 'dart:convert';
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
  late final Stream<String> _responses;

  final Address _telloAddress;

  final Queue<Completer<String>> _responseQueue = Queue<Completer<String>>();

  final Cleaner<StreamSubscription<String>> _subscriptionCleaner =
      Cleaner<StreamSubscription<String>>(
          (StreamSubscription<String> subscription) {
    subscription.cancel();
  });

  final Cleaner<Timer> _timeoutCleaner = Cleaner<Timer>((Timer timer) {
    timer.cancel();
  });

  final Duration? _timeout;

  static Future<TelloSocket> telloSocket(
      {Duration? timeout = const Duration(seconds: 12),
      Address? telloAddress,
      Address? localAddress}) async {
    final Address _localAddress =
        localAddress ?? Address(ip: InternetAddress.anyIPv4, port: 9000);

    return TelloSocket._(
        await RawDatagramSocket.bind(_localAddress.ip, _localAddress.port),
        telloAddress ??
            Address(ip: InternetAddress("192.168.10.1"), port: 8889),
        timeout);
  }

  TelloSocket._(this._socket, this._telloAddress, this._timeout) {
    _responses = _socket
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

      return utf8.decode(receivedData.data).trim();
    }).asBroadcastStream(
            onListen: _subscriptionCleaner.add,
            onCancel: _subscriptionCleaner.remove);

    _responses.listen((String response) {
      if (_responseQueue.isEmpty) return;

      _responseQueue.removeFirst().complete(response);
    });
  }

  bool get waiting => _responseQueue.isNotEmpty;

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
  }

  Future<String> receive() {
    Completer<String> responseWaiter = Completer<String>();

    final Duration? timeout = _timeout;

    if (timeout != null) {
      StackTrace outerStackTrace = StackTrace.current;

      _timeoutCleaner.add(Timer(timeout, () {
        if (responseWaiter.isCompleted) return;

        responseWaiter.completeError(
            TimeoutException(
                "The Tello's reponse didn't arrive within the Timeout's duration."),
            outerStackTrace);
      }));
    }

    _responseQueue.add(responseWaiter);

    return responseWaiter.future;
  }

  Stream<String> get responses => _responses;

  void disconnect() {
    _subscriptionCleaner.cleanup();
    _timeoutCleaner.cleanup();
    _socket.close();
  }
}

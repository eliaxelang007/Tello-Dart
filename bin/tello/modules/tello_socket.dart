import 'dart:async';
import 'dart:convert';
import 'dart:io';

import "tello_logger.dart";

class _Address {
  InternetAddress ip;
  int port;

  _Address(this.ip, this.port);

  @override
  String toString() {
    return "($ip, $port)";
  }
}

class TelloSocket 
{

    final TelloLogger _telloLogger;
    
    final Future<RawDatagramSocket> _telloClient;
    final _Address _telloAddress;

    final int _telloResponseTimeoutSecs;

        TelloSocket
        (
          TelloLogger telloLogger, 
          [int telloResponseTimeoutSecs = 12, 
          String telloIP = "192.168.10.1", 
          int telloPort = 8889, 
          String telloClientIp = "0.0.0.0", 
          int telloClientPort = 9000]
        ):
        _telloResponseTimeoutSecs = telloResponseTimeoutSecs,
        _telloLogger = telloLogger,
        _telloClient = RawDatagramSocket.bind(InternetAddress(telloClientIp), telloClientPort),
        _telloAddress = _Address(InternetAddress(telloIP), telloPort);

        Future<String> sendCommand(final String toSend) async
        {
            await sendData(toSend);
            return await receiveData();
        }

        Future<void> sendData(String stringData) async
        {
            InternetAddress telloAddress = _telloAddress.ip;
            int telloPort = _telloAddress.port;

            int sendResult = (await _telloClient).send(utf8.encode(stringData), telloAddress, telloPort);

            if (sendResult <= -1) throw SocketException("We couldn't send '$stringData' to your Tello.", address: telloAddress, port: telloPort);

            _telloLogger.logData
            (
                "Sent '$stringData' to '$_telloAddress'"
            );
        }

        Future<String> receiveData() async
        {
            RawDatagramSocket telloClient = (await _telloClient);

            Datagram? receivedData;

            DateTime start = DateTime.now();

            while (receivedData == null && DateTime.now().difference(start).inSeconds <= _telloResponseTimeoutSecs) {
              receivedData = telloClient.receive();
            }

            if (receivedData == null) 
            {
              throw SocketException("We couldn't receive data from your Tello.");
            }

            InternetAddress receivedDataAddress = receivedData.address;

            if (receivedDataAddress != _telloAddress.ip) 
            {
              throw SocketException("Unknown connection from ip $receivedDataAddress");
            }

            String data = utf8.decode(receivedData.data);

            _telloLogger.logData
            (
              "Received '$data' from $_telloAddress"
            );

            return data.trim();
        }
}
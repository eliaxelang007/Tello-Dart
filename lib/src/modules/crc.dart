import 'dart:typed_data';

import 'package:handy/handy.dart';

typedef CrcCache = Cache<int, int, int>;

CrcCache crcCoefficientCache(int polynomial) => CrcCache((int byte) {
      var crc = 0;

      for (var i = 0; i < 8; i++) {
        final mix =
            (crc ^ byte) & 0x1; // Zeroes out all bits except for the last 1

        crc >>= 1;

        if (mix != 0) crc ^= polynomial;

        byte >>= 1;
      }

      return crc;
    },
        sanitizer: (int byte) =>
            byte & 0xFF /* Zeroes out all bits except for the last 8 */);

CrcCache crc8Cache =
    crcCoefficientCache(0x8C /* CRC-8-Dallas/Maxim Polynomial */);

int calculateCrc8(Uint8List buffer) {
  var crc = 0x77;

  for (var byte in buffer) {
    crc = crc8Cache(crc ^ byte);
  }

  return crc;
}

CrcCache crc16Cache = crcCoefficientCache(0x8408 /* CRC-16-CCITT Polynomial */);

int calculateCrc16(Uint8List buffer) {
  var crc = 0x3692;

  for (var byte in buffer) {
    crc = (crc >> 8) ^ crc16Cache(crc ^ byte);
  }

  return crc;
}

/* -- References -- */
// https://github.com/hanyazou/TelloPy/blob/2e3ff77f87448307d6d2656c91ac80e2fb352193/tellopy/_internal/crc.py#L36
// https://stackoverflow.com/questions/29214301/ios-how-to-calculate-crc-8-dallas-maxim-of-nsdata
// https://github.com/ETLCPP/crc-table-generator/blob/master/Crc8.cpp
// http://www.sanity-free.com/134/standard_crc_16_in_csharp.html
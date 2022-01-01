import 'dart:io';

class Logger {
  static bool shouldLog = false;
  static final List<String> _log = [];

  Logger._();

  static void writeLog(String logLocation) async {
    await File(logLocation).writeAsString(_log.join('\n'));
  }

  static void log(String toLog) {
    if (shouldLog) {
      _log.add(toLog);
      print(toLog);
    }
  }
}

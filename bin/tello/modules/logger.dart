import 'dart:io';

class Logger
{
    final bool _shouldLog;
    final List<String> _log = [];

    Logger(bool shouldLog): _shouldLog = shouldLog;

    void writeLog(String logLocation) async
    {
      await File(logLocation).writeAsString(_log.join('\n'));
    }

    void logData(String toLog)
    {
        if (_shouldLog) 
        {
            _log.add(toLog);
            print(toLog);
        }
    }
}
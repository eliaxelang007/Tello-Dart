import 'dart:io';

class TelloLogger
{
    final bool _telloLogging;
    final List<String> _log = [];

    TelloLogger(bool telloLogging): _telloLogging = telloLogging;

    void writeLog(String logLocation) async
    {
      await File(logLocation).writeAsString(_log.join('\n'));
    }

    void logData(String toLog)
    {
        if(_telloLogging) 
        {
            _log.add(toLog);
            print(toLog);
        }
    }
}
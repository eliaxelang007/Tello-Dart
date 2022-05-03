class TelloError implements Exception {
  final dynamic message;

  TelloError([this.message]);

  @override
  String toString() =>
      (message != null) ? "$TelloError: $message" : "$TelloError";
}

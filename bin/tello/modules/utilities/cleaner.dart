class Cleaner<T> {
  final Set<T> _inUse;
  final void Function(T) _clean;

  Cleaner({Set<T>? inUse, void Function(T)? cleaner})
      : _inUse = inUse ?? {},
        _clean = cleaner ?? ((_) {});

  void add(T inUse) {
    if (_inUse.contains(inUse)) {
      throw FormatException(
          "A collision occured while trying to store a listener in a map.");
    }
    _inUse.add(inUse);
  }

  void remove(T unused) {
    if (!_inUse.contains(unused)) {
      throw FormatException("Tried to remove a listener that wasn't stored.");
    }

    _inUse.remove(unused);
  }

  void cleanup() {
    for (T used in _inUse) {
      _clean(used);
    }
  }
}

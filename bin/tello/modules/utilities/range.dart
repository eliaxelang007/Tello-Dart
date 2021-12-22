class Range {
  final int minimum;
  final int maximum;

  const Range(this.minimum, this.maximum);
  const Range.fromList(final List list)
      : minimum = 0,
        maximum = list.length - 1;

  bool call<T extends num>(T value) {
    return value <= maximum && value >= minimum;
  }

  num clamp<T extends num>(T value) {
    if (value >= maximum) {
      return maximum;
    }

    if (value <= minimum) {
      return minimum;
    }

    return value;
  }

  @override
  String toString() => "($minimum-$maximum)";
}

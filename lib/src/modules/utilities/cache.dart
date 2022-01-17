class Cache<I, O> {
  final Map<I, O> _cachedOutputs = {};
  final O Function(I) caclulator;
  final I Function(I) inputSanitizer;

  Cache(this.caclulator, {I Function(I)? inputSanitizer})
      : inputSanitizer = inputSanitizer ?? ((value) => value);

  O call(I input) {
    I sanitizedInput = inputSanitizer(input);

    O? cachedOutput = _cachedOutputs[sanitizedInput];

    if (cachedOutput != null) return cachedOutput;

    return _calculate(sanitizedInput);
  }

  O calculate(I input) {
    return _calculate(inputSanitizer(input));
  }

  O _calculate(I input) {
    O result = caclulator(input);

    _cachedOutputs[input] = result;

    return result;
  }
}

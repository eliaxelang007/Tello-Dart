class Cache<I, O> {
  final Map<I, O> _cachedOutputs = {};
  final O Function(I) generator;
  final I Function(I) inputSanitizer;

  Cache(this.generator, {I Function(I)? inputSanitizer})
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
    O result = generator(input);

    _cachedOutputs[input] = result;

    return result;
  }
}

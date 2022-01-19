import 'dart:math';

int mask(int number, {int bits = 8}) => number & (pow(2, bits).floor() - 1);

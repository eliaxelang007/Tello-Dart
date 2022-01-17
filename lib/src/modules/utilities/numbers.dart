import 'dart:math';

int mask(int number, {required int bits}) =>
    number & (pow(2, bits).floor() - 1);

extension EnumExtension on Enum {
  String toShortString() => "$this".split('.').last;
}

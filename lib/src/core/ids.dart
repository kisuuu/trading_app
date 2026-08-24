/// Monotonic identifier source for locally created records.
///
/// Timestamp-prefixed so ids sort chronologically, with a counter suffix so two
/// records created in the same millisecond cannot collide. A UUID package would
/// work too, but this keeps the dependency list short and the ids readable.
abstract final class Ids {
  static int _sequence = 0;

  static String next(String prefix) {
    _sequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }
}

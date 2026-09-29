import 'package:pgntrainingreader/core/utilities/id_generator.dart';

/// Produces repeatable identifiers for tests without relying on randomness.
final class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator({this.prefix = 'test-id'});

  final String prefix;
  int _next = 1;

  @override
  String generateId() => '$prefix-${_next++}';
}

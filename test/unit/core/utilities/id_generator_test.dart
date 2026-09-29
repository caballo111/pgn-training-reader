import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';

import '../../../support/fake_id_generator.dart';

void main() {
  test('random generator creates version 4 UUIDs', () {
    final generator = RandomIdGenerator(random: Random(42));
    final id = generator.generateId();

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('fake generator returns a deterministic sequence', () {
    final IdGenerator generator = FakeIdGenerator(prefix: 'exercise');

    expect(generator.generateId(), 'exercise-1');
    expect(generator.generateId(), 'exercise-2');
    expect(generator.generateId(), 'exercise-3');
  });
}

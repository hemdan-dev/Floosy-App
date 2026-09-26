import 'package:flutter_test/flutter_test.dart';

import 'package:floosy/core/hybrid_clock.dart';
import 'package:floosy/core/money.dart';
import 'package:floosy/migration/legacy_parser.dart';

void main() {
  test('money parsing keeps minor-unit precision', () {
    expect(Money.parseMinor('1,234.56 EGP'), 123456);
    expect(Money.parseMinor('١٢٫٥٠'), 1250);
  });

  test('hybrid clock stamps sort causally', () {
    final clock = HybridClock(
      'device-a',
      now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    final first = clock.tick();
    final second = clock.tick();
    expect(HybridClock.compare(first, second), lessThan(0));
  });

  test('concatenated legacy JSON is separated safely', () {
    final values = decodeConcatenatedJson('{"a":"}"}\n[{"b":2}]');
    expect(values, hasLength(2));
    expect((values.first as Map)['a'], '}');
  });
}

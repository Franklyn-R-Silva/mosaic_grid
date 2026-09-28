import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_grid/src/rendering/mosaic_ledger.dart';

/// The items whose slots meet `[start, end]`, found the slow way.
(int, int)? bruteWindow(MosaicLedger ledger, double start, double end) {
  int? first;
  int? last;
  for (var i = 0; i < ledger.committedCount; i++) {
    final offset = ledger.slotOffset(i);
    if (offset + ledger.slotExtent(i) >= start && offset < end) {
      first ??= i;
      last = i;
    }
  }
  return first == null ? null : (first, last!);
}

void main() {
  final builders = <String, MosaicLedger Function(int columns, double gap)>{
    'rows': (columns, gap) => RowsLedger(columnCount: columns, rowGap: gap),
    'masonry': (columns, gap) =>
        MasonryLedger(columnCount: columns, rowGap: gap),
  };

  for (final MapEntry(key: name, value: create) in builders.entries) {
    group('$name ledger matches a brute-force model', () {
      test('window, for random grids and bands', () {
        final random = math.Random(7);
        for (var round = 0; round < 60; round++) {
          final columns = 1 + random.nextInt(5);
          final ledger = create(columns, random.nextInt(3) * 4.0);
          final count = random.nextInt(300);
          for (var i = 0; i < count; i++) {
            final span = random.nextInt(10) == 0 ? 1 + random.nextInt(4) : 1;
            // Now and then a very tall tile, to stretch one column.
            final extent = random.nextInt(25) == 0
                ? 800.0 + random.nextInt(3000)
                : 10.0 + random.nextInt(120);
            ledger
              ..prepare(span)
              ..add(span, extent);
          }
          ledger.close();
          final total = ledger.contentExtent;
          for (var probe = 0; probe < 40; probe++) {
            final start = random.nextDouble() * (total + 200) - 100;
            final end = start + random.nextDouble() * 900;
            expect(
              ledger.window(start, end),
              bruteWindow(ledger, start, end),
              reason: 'round $round, band $start..$end',
            );
          }
        }
      });

      test('truncate and re-add rebuilds the same placement', () {
        final random = math.Random(11);
        for (var round = 0; round < 40; round++) {
          final columns = 1 + random.nextInt(5);
          final gap = random.nextInt(3) * 4.0;
          final spans = List.generate(
            200,
            (_) => random.nextInt(8) == 0 ? 1 + random.nextInt(3) : 1,
          );
          final extents = List.generate(200, (_) => 10.0 + random.nextInt(200));

          void fill(MosaicLedger ledger, int from) {
            for (var i = from; i < spans.length; i++) {
              ledger
                ..prepare(spans[i])
                ..add(spans[i], extents[i]);
            }
            ledger.close();
          }

          final fresh = create(columns, gap);
          fill(fresh, 0);

          final truncated = create(columns, gap);
          fill(truncated, 0);
          truncated.truncate(random.nextInt(spans.length));
          fill(truncated, truncated.measuredCount);

          expect(truncated.committedCount, fresh.committedCount);
          expect(truncated.contentExtent, fresh.contentExtent);
          expect(truncated.coveredUntil, fresh.coveredUntil);
          for (var i = 0; i < fresh.committedCount; i++) {
            expect(truncated.slotOffset(i), fresh.slotOffset(i));
            expect(truncated.columnOf(i), fresh.columnOf(i));
          }
        }
      });
    });
  }

  test('masonry window stays quick when one column is far taller', () {
    // One very tall tile in column 0, then many short ones filling column 1.
    // A band near the end still reaches back to item 0.
    final ledger = MasonryLedger(columnCount: 2, rowGap: 0)..add(1, 100000);
    for (var i = 0; i < 50000; i++) {
      ledger.add(1, 10);
    }
    final watch = Stopwatch()..start();
    (int, int)? window;
    for (var i = 0; i < 1000; i++) {
      window = ledger.window(90000, 90100);
    }
    watch.stop();
    expect(window, bruteWindow(ledger, 90000, 90100));
    expect(window!.$1, 0);
    // A thousand lookups: a per-column binary search, not a walk over 50k items.
    expect(watch.elapsedMilliseconds, lessThan(250));
  });

  test('masonry truncate near the end is quick', () {
    final ledger = MasonryLedger(columnCount: 3, rowGap: 4);
    for (var i = 0; i < 100000; i++) {
      ledger.add(1, 10.0 + i % 50);
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      ledger
        ..truncate(99990)
        ..add(1, 20);
    }
    watch.stop();
    expect(ledger.committedCount, 99991);
    expect(watch.elapsedMilliseconds, lessThan(250));
  });
}

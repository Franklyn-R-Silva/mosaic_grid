import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:mosaic_grid/src/rendering/mosaic_ledger.dart';

void main() {
  group('MosaicColumns', () {
    test('count is fixed', () {
      expect(const MosaicColumns.count(3).resolve(10, 8), 3);
      expect(const MosaicColumns.count(3).resolve(10000, 8), 3);
    });

    test('minExtent keeps tiles at least that wide, capped', () {
      const columns = MosaicColumns.minExtent(380, maxCount: 3);
      expect(columns.resolve(300, 8), 1); // never below one
      expect(columns.resolve(767, 8), 1); // 2 * 380 + 8 = 768
      expect(columns.resolve(768, 8), 2);
      expect(columns.resolve(1156, 8), 3);
      expect(columns.resolve(5000, 8), 3); // the cap
      expect(const MosaicColumns.minExtent(100).resolve(1000, 0), 10);
    });

    test('maxExtent keeps tiles at most that wide', () {
      const columns = MosaicColumns.maxExtent(430);
      expect(columns.resolve(430, 10), 1);
      expect(columns.resolve(431, 10), 2);
      expect(columns.resolve(870, 10), 2); // 2 * 430 + 10
      expect(columns.resolve(871, 10), 3);
    });

    test('equality', () {
      expect(
        const MosaicColumns.minExtent(380, maxCount: 3),
        const MosaicColumns.minExtent(380, maxCount: 3),
      );
      expect(const MosaicColumns.count(2), isNot(const MosaicColumns.count(3)));
    });
  });

  group('RowsLedger', () {
    test('a row is as tall as its tallest item', () {
      final ledger = RowsLedger(columnCount: 3, rowGap: 10);
      for (final extent in [50.0, 80.0, 30.0, 40.0]) {
        ledger
          ..prepare(1)
          ..add(1, extent);
      }
      expect(ledger.committedCount, 3); // the second row is still open
      expect(ledger.measuredCount, 4);
      expect([for (var i = 0; i < 3; i++) ledger.slotOffset(i)], [0, 0, 0]);
      expect(ledger.slotExtent(1), 80);
      expect(ledger.coveredUntil, 90);

      ledger.close();
      expect(ledger.committedCount, 4);
      expect(ledger.slotOffset(3), 90);
      expect(ledger.slotExtent(3), 40);
      expect(ledger.contentExtent, 130);
    });

    test('an item that does not fit moves to the next row', () {
      final ledger = RowsLedger(columnCount: 3, rowGap: 0);
      for (final span in [1, 2, 2, 1, 5]) {
        ledger
          ..prepare(span)
          ..add(span, 10);
      }
      ledger.close();
      expect([for (var i = 0; i < 5; i++) ledger.columnOf(i)], [0, 1, 0, 2, 0]);
      expect([for (var i = 0; i < 5; i++) ledger.spanOf(i)], [1, 2, 2, 1, 3]);
      expect(
        [for (var i = 0; i < 5; i++) ledger.slotOffset(i)],
        [0, 0, 10, 10, 20],
      );
    });

    test('prepare commits the open row before measuring the next item', () {
      final ledger = RowsLedger(columnCount: 2, rowGap: 0)..add(1, 10);
      expect(ledger.committedCount, 0);
      ledger.prepare(2);
      expect(ledger.committedCount, 1);
    });

    test('truncate drops the whole row that holds the index', () {
      final ledger = RowsLedger(columnCount: 2, rowGap: 5);
      for (var i = 0; i < 6; i++) {
        ledger.add(1, 10.0 + i);
      }
      ledger.truncate(3); // inside the second row (items 2 and 3)
      expect(ledger.measuredCount, 2);
      expect(ledger.committedCount, 2);
      expect(ledger.contentExtent, 11);
      ledger
        ..add(1, 100)
        ..add(1, 1);
      expect(ledger.slotOffset(2), 16);
      expect(ledger.slotExtent(3), 100);
    });

    test('truncate at the item that closed a row reopens that row', () {
      final ledger = RowsLedger(columnCount: 3, rowGap: 0)
        ..add(1, 10)
        ..add(1, 10)
        ..add(2, 10); // does not fit: closes the first row, a column free
      expect(ledger.committedCount, 2);
      ledger.truncate(2);
      expect(ledger.measuredCount, 0);
      ledger
        ..add(1, 10)
        ..add(1, 10)
        ..add(1, 10);
      expect(ledger.columnOf(2), 2);
      expect(ledger.slotOffset(2), 0);
    });

    test('reopenTail lets new items join a row closed by the end', () {
      final ledger = RowsLedger(columnCount: 3, rowGap: 0)
        ..add(1, 10)
        ..add(1, 10)
        ..close();
      expect(ledger.committedCount, 2);
      ledger.reopenTail();
      expect(ledger.committedCount, 0);
      expect(ledger.measuredCount, 0);
    });

    test('reopenTail leaves a full last row alone', () {
      final ledger = RowsLedger(columnCount: 2, rowGap: 0)
        ..add(1, 10)
        ..add(1, 10)
        ..close()
        ..reopenTail();
      expect(ledger.committedCount, 2);
    });

    test('window finds the rows that meet the band', () {
      final ledger = RowsLedger(columnCount: 2, rowGap: 0);
      for (var i = 0; i < 20; i++) {
        ledger.add(1, 100);
      }
      expect(ledger.window(0, 150), (0, 3));
      expect(ledger.window(250, 450), (4, 9));
      expect(ledger.window(2000, 3000), isNull);
    });
  });

  group('MasonryLedger', () {
    test('each item drops into the column that ends first', () {
      final ledger = MasonryLedger(columnCount: 2, rowGap: 0);
      for (final extent in [100.0, 50.0, 30.0, 80.0]) {
        ledger.add(1, extent);
      }
      expect([for (var i = 0; i < 4; i++) ledger.columnOf(i)], [0, 1, 1, 1]);
      expect(
        [for (var i = 0; i < 4; i++) ledger.slotOffset(i)],
        [0, 0, 50, 80],
      );
      expect(ledger.contentExtent, 160);
      expect(ledger.coveredUntil, 100);
    });

    test('ties go to the leftmost column', () {
      final ledger = MasonryLedger(columnCount: 3, rowGap: 0);
      for (var i = 0; i < 3; i++) {
        ledger.add(1, 10);
      }
      expect([for (var i = 0; i < 3; i++) ledger.columnOf(i)], [0, 1, 2]);
    });

    test('a spanning item takes the run of columns that ends first', () {
      final ledger = MasonryLedger(columnCount: 3, rowGap: 0)
        ..add(1, 100) // column 0
        ..add(1, 20) // column 1
        ..add(1, 40) // column 2
        ..add(2, 10); // columns 1-2, below the taller of the two
      expect(ledger.columnOf(3), 1);
      expect(ledger.slotOffset(3), 40);
    });

    test('truncate replays what is left', () {
      final ledger = MasonryLedger(columnCount: 2, rowGap: 4);
      for (final extent in [100.0, 50.0, 30.0, 80.0]) {
        ledger.add(1, extent);
      }
      ledger
        ..truncate(2)
        ..add(1, 10);
      expect(ledger.columnOf(2), 1);
      expect(ledger.slotOffset(2), 54);
      expect(ledger.contentExtent, 100);
    });

    test('window reaches back into a tall column', () {
      final ledger = MasonryLedger(columnCount: 2, rowGap: 0)
        ..add(1, 1000); // column 0, tall
      for (var i = 0; i < 40; i++) {
        ledger.add(1, 100);
      }
      // Item 0 still reaches the band at 500..600, far behind in index.
      expect(ledger.window(500, 600), (0, 6));
      // Past it, both columns fill in turn: 21/22 at 1500, 23/24 at 1600.
      expect(ledger.window(1510, 1650), (21, 24));
    });
  });
}

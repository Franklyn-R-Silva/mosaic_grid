import 'dart:math' as math;

import '../mosaic_layout.dart';

/// The placement record behind a mosaic grid: for every item measured so far,
/// which columns it occupies and where its slot starts and ends along the main
/// axis.
///
/// Items are always placed in index order, starting from item 0, so the
/// record is a prefix of the item list and every position in it is exact. That
/// is what lets the grid scroll back up without guessing, and jump straight to
/// an item it has already placed.
///
/// An item is *measured* once its natural extent has been added, and
/// *committed* once its slot is final. In the rows layout the two differ for
/// the items of the row still being filled, whose height is not known until
/// the row is complete; in masonry an item is committed as soon as it is
/// measured.
///
/// This class knows nothing about render objects, so it can be tested on its
/// own.
abstract class MosaicLedger {
  MosaicLedger._({required this.columnCount, required this.rowGap})
    : assert(columnCount > 0),
      assert(rowGap >= 0);

  /// Creates the ledger that matches [layout].
  factory MosaicLedger.forLayout(
    MosaicLayout layout, {
    required int columnCount,
    required double rowGap,
  }) {
    return switch (layout) {
      MosaicRowsLayout() => RowsLedger(
        columnCount: columnCount,
        rowGap: rowGap,
      ),
      MosaicMasonryLayout() => MasonryLedger(
        columnCount: columnCount,
        rowGap: rowGap,
      ),
    };
  }

  /// The number of columns the cross axis is split into.
  final int columnCount;

  /// The main-axis gap between vertically neighbouring tiles.
  final double rowGap;

  /// Whether this ledger places items the way [layout] does.
  bool matches(MosaicLayout layout);

  /// Clamps a requested span to what the grid can honour.
  int clampSpan(int span) => span < 1 ? 1 : math.min(span, columnCount);

  /// The number of items whose natural extent has been recorded.
  int get measuredCount;

  /// The number of items whose slot is final. Always a prefix: items
  /// `0 .. committedCount - 1`.
  int get committedCount;

  /// The main-axis offset before which no item that is not committed yet can
  /// start. Everything that will ever be placed after the committed items
  /// starts at or after this offset.
  double get coveredUntil;

  /// The main-axis extent of the committed items, without a trailing gap.
  double get contentExtent;

  /// Where the slot of committed item [index] starts on the main axis.
  double slotOffset(int index);

  /// The main-axis extent of the slot of committed item [index]: the item's
  /// own extent in masonry, the height of its row in the rows layout.
  double slotExtent(int index);

  /// The natural extent measured for item [index].
  double naturalExtent(int index);

  /// The first column occupied by item [index], counted from the start edge.
  int columnOf(int index);

  /// The number of columns occupied by item [index].
  int spanOf(int index);

  /// Must be called with the span of the next item before measuring it.
  ///
  /// In the rows layout this closes the open row when the item would not fit
  /// in it, which may commit items without measuring the next one.
  void prepare(int span);

  /// Records the next item, of [span] columns and [naturalExtent] along the
  /// main axis.
  void add(int span, double naturalExtent);

  /// Commits everything measured so far; called once the list has run out of
  /// items.
  void close();

  /// Undoes a [close] that happened only because the list ran out, so items
  /// added to the list later can still join the last row.
  void reopenTail();

  /// Forgets item [index] and everything after it, so they get measured and
  /// placed again.
  void truncate(int index);

  /// The range of committed items whose slots meet `[start, end]`, or null if
  /// none do.
  ///
  /// The range is contiguous in index order and may include items that are
  /// themselves outside the band — in masonry, a short item in one column can
  /// sit between two tall ones that reach into it.
  (int, int)? window(double start, double end);
}

/// The ledger of [MosaicLayout.rows].
class RowsLedger extends MosaicLedger {
  /// Creates an empty rows ledger.
  RowsLedger({required super.columnCount, required super.rowGap}) : super._();

  // Per measured item.
  final List<int> _itemRow = <int>[];
  final List<int> _itemColumn = <int>[];
  final List<int> _itemSpan = <int>[];
  final List<double> _itemNatural = <double>[];

  // Per committed row.
  final List<int> _rowFirst = <int>[];
  final List<int> _rowColumnsUsed = <int>[];
  final List<double> _rowOffset = <double>[];
  final List<double> _rowExtent = <double>[];

  // The row being filled, if any.
  int? _openFirst;
  int _openUsed = 0;

  // Whether the last row was closed only because the list ran out.
  bool _closedAtEnd = false;

  @override
  bool matches(MosaicLayout layout) => layout is MosaicRowsLayout;

  @override
  int get measuredCount => _itemNatural.length;

  @override
  int get committedCount => _openFirst ?? _itemNatural.length;

  /// The number of committed rows.
  int get rowCount => _rowFirst.length;

  @override
  double get contentExtent =>
      _rowFirst.isEmpty ? 0.0 : _rowOffset.last + _rowExtent.last;

  double get _nextRowOffset => _rowFirst.isEmpty ? 0.0 : contentExtent + rowGap;

  @override
  double get coveredUntil => _nextRowOffset;

  @override
  double slotOffset(int index) => _rowOffset[_committedRow(index)];

  @override
  double slotExtent(int index) => _rowExtent[_committedRow(index)];

  int _committedRow(int index) {
    assert(index >= 0 && index < committedCount, 'item $index not committed');
    return _itemRow[index];
  }

  @override
  double naturalExtent(int index) => _itemNatural[index];

  @override
  int columnOf(int index) => _itemColumn[index];

  @override
  int spanOf(int index) => _itemSpan[index];

  @override
  void prepare(int span) {
    final clamped = clampSpan(span);
    if (_openFirst != null && _openUsed + clamped > columnCount) {
      _commitOpenRow();
    }
  }

  @override
  void add(int span, double naturalExtent) {
    final clamped = clampSpan(span);
    prepare(clamped);
    _closedAtEnd = false;
    _openFirst ??= _itemNatural.length;
    _itemRow.add(_rowFirst.length);
    _itemColumn.add(_openUsed);
    _itemSpan.add(clamped);
    _itemNatural.add(naturalExtent);
    _openUsed += clamped;
    if (_openUsed >= columnCount) {
      _commitOpenRow();
    }
  }

  void _commitOpenRow() {
    final first = _openFirst;
    if (first == null) {
      return;
    }
    var extent = 0.0;
    for (var i = first; i < _itemNatural.length; i++) {
      extent = math.max(extent, _itemNatural[i]);
    }
    final offset = _nextRowOffset;
    _rowFirst.add(first);
    _rowColumnsUsed.add(_openUsed);
    _rowOffset.add(offset);
    _rowExtent.add(extent);
    _openFirst = null;
    _openUsed = 0;
  }

  @override
  void close() {
    if (_openFirst != null) {
      _commitOpenRow();
      _closedAtEnd = true;
    }
  }

  @override
  void reopenTail() {
    if (!_closedAtEnd || _rowFirst.isEmpty) {
      return;
    }
    _closedAtEnd = false;
    if (_rowColumnsUsed.last < columnCount) {
      truncate(_rowFirst.last);
    }
  }

  @override
  void truncate(int index) {
    if (index >= _itemNatural.length) {
      return;
    }
    // A row is only ever kept whole: drop the row that holds [index].
    final row = _itemRow[index];
    final first = row < _rowFirst.length ? _rowFirst[row] : _openFirst!;
    _itemRow.length = first;
    _itemColumn.length = first;
    _itemSpan.length = first;
    _itemNatural.length = first;
    if (row < _rowFirst.length) {
      _rowFirst.length = row;
      _rowColumnsUsed.length = row;
      _rowOffset.length = row;
      _rowExtent.length = row;
    }
    _openFirst = null;
    _openUsed = 0;
    _closedAtEnd = false;
  }

  @override
  (int, int)? window(double start, double end) {
    final rows = _rowFirst.length;
    if (rows == 0) {
      return null;
    }
    // First row that reaches the band.
    var lo = 0;
    var hi = rows;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_rowOffset[mid] + _rowExtent[mid] >= start) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    final firstRow = lo;
    // First row that starts at or past the end of the band.
    lo = firstRow;
    hi = rows;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_rowOffset[mid] >= end) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    final lastRow = lo - 1;
    if (firstRow >= rows || lastRow < firstRow) {
      return null;
    }
    final last =
        (lastRow + 1 < rows ? _rowFirst[lastRow + 1] : committedCount) - 1;
    return (_rowFirst[firstRow], last);
  }
}

/// The ledger of [MosaicLayout.masonry].
class MasonryLedger extends MosaicLedger {
  /// Creates an empty masonry ledger.
  MasonryLedger({required super.columnCount, required super.rowGap})
    : _frontier = List<double>.filled(columnCount, 0.0),
      _columnItems = List<List<int>>.generate(columnCount, (_) => <int>[]),
      super._();

  final List<double> _offset = <double>[];
  final List<double> _natural = <double>[];
  final List<int> _column = <int>[];
  final List<int> _span = <int>[];

  // The items covering each column, in index order. Tiles in a column are
  // stacked, so along each list both offsets and ends only grow: every
  // question about a column is a binary search, whatever the other columns do.
  final List<List<int>> _columnItems;

  // Where the next tile of each column would start, gap included.
  final List<double> _frontier;
  double _contentExtent = 0.0;

  @override
  bool matches(MosaicLayout layout) => layout is MosaicMasonryLayout;

  @override
  int get measuredCount => _natural.length;

  @override
  int get committedCount => _natural.length;

  @override
  double get contentExtent => _contentExtent;

  @override
  double get coveredUntil => _frontier.reduce(math.min);

  @override
  double slotOffset(int index) => _offset[index];

  @override
  double slotExtent(int index) => _natural[index];

  @override
  double naturalExtent(int index) => _natural[index];

  @override
  int columnOf(int index) => _column[index];

  @override
  int spanOf(int index) => _span[index];

  double _end(int index) => _offset[index] + _natural[index];

  @override
  void prepare(int span) {}

  @override
  void add(int span, double naturalExtent) {
    final clamped = clampSpan(span);
    var bestColumn = 0;
    var bestTop = double.infinity;
    for (var c = 0; c + clamped <= columnCount; c++) {
      var top = _frontier[c];
      for (var k = c + 1; k < c + clamped; k++) {
        top = math.max(top, _frontier[k]);
      }
      if (top < bestTop) {
        bestTop = top;
        bestColumn = c;
      }
    }
    final index = _natural.length;
    _offset.add(bestTop);
    _natural.add(naturalExtent);
    _column.add(bestColumn);
    _span.add(clamped);
    final next = bestTop + naturalExtent + rowGap;
    for (var k = bestColumn; k < bestColumn + clamped; k++) {
      _frontier[k] = next;
      _columnItems[k].add(index);
    }
    _contentExtent = math.max(_contentExtent, bestTop + naturalExtent);
  }

  @override
  void close() {}

  @override
  void reopenTail() {}

  @override
  void truncate(int index) {
    if (index >= _natural.length) {
      return;
    }
    // Pop what goes from the top of each column: a column then ends where its
    // last remaining tile ends. No replay of the items that stay.
    _contentExtent = 0.0;
    for (var c = 0; c < columnCount; c++) {
      final items = _columnItems[c];
      while (items.isNotEmpty && items.last >= index) {
        items.removeLast();
      }
      if (items.isEmpty) {
        _frontier[c] = 0.0;
      } else {
        final end = _end(items.last);
        _frontier[c] = end + rowGap;
        _contentExtent = math.max(_contentExtent, end);
      }
    }
    _offset.length = index;
    _natural.length = index;
    _column.length = index;
    _span.length = index;
  }

  @override
  (int, int)? window(double start, double end) {
    int? first;
    int? last;
    for (final items in _columnItems) {
      // The first tile of the column that reaches the band…
      final low = _lowerBound(items, (i) => _end(i) >= start);
      if (low == items.length || _offset[items[low]] >= end) {
        continue; // …if it starts before the band ends.
      }
      // …and the last one that starts before the band ends.
      final high = _lowerBound(items, (i) => _offset[i] >= end) - 1;
      final lowIndex = items[low];
      final highIndex = items[high];
      first = first == null ? lowIndex : math.min(first, lowIndex);
      last = last == null ? highIndex : math.max(last, highIndex);
    }
    return first == null ? null : (first, last!);
  }

  // The first position in [items] where [test] holds; [test] must be false
  // then true along the list.
  static int _lowerBound(List<int> items, bool Function(int index) test) {
    var lo = 0;
    var hi = items.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (test(items[mid])) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }
}

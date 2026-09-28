import 'package:flutter/foundation.dart';

/// How many columns a mosaic grid splits its cross axis into.
///
/// The count is resolved on every layout from the cross-axis extent the grid
/// is given, so a grid inside a resizable window or a split pane picks its
/// column count from the space it actually has, not from the screen size.
///
/// "Extent" is measured along the cross axis: the width of a tile in a
/// vertical grid, its height in a horizontal one.
@immutable
sealed class MosaicColumns {
  const MosaicColumns();

  /// Always exactly [count] columns.
  const factory MosaicColumns.count(int count) = MosaicFixedColumns;

  /// As many columns as fit while keeping every tile at least [minExtent]
  /// wide, capped at [maxCount].
  ///
  /// Use it when a tile has a minimum readable width — below it, content
  /// starts wrapping or truncating — and more columns only make sense while
  /// there is room for them.
  const factory MosaicColumns.minExtent(double minExtent, {int? maxCount}) =
      MosaicMinExtentColumns;

  /// The fewest columns that keep every tile at most [maxExtent] wide.
  ///
  /// Use it when tiles should not grow past a comfortable width, and a wider
  /// grid should gain columns instead.
  const factory MosaicColumns.maxExtent(double maxExtent) =
      MosaicMaxExtentColumns;

  /// Resolves the number of columns for a cross axis of [crossAxisExtent],
  /// with [gap] between neighbouring columns. Always at least 1.
  int resolve(double crossAxisExtent, double gap);
}

/// A fixed number of columns. See [MosaicColumns.count].
final class MosaicFixedColumns extends MosaicColumns {
  /// Creates a fixed column count.
  const MosaicFixedColumns(this.count) : assert(count > 0);

  /// The number of columns.
  final int count;

  @override
  int resolve(double crossAxisExtent, double gap) => count;

  @override
  bool operator ==(Object other) =>
      other is MosaicFixedColumns && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'MosaicColumns.count($count)';
}

/// Columns derived from a minimum tile extent. See [MosaicColumns.minExtent].
final class MosaicMinExtentColumns extends MosaicColumns {
  /// Creates columns that keep tiles at least [minExtent] wide.
  const MosaicMinExtentColumns(this.minExtent, {this.maxCount})
    : assert(minExtent > 0),
      assert(maxCount == null || maxCount > 0);

  /// The smallest extent a tile may have.
  final double minExtent;

  /// The largest number of columns, however much room there is.
  final int? maxCount;

  @override
  int resolve(double crossAxisExtent, double gap) {
    // n tiles and n - 1 gaps must fit: n * minExtent + (n - 1) * gap <= extent.
    final fit = ((crossAxisExtent + gap) / (minExtent + gap)).floor();
    final count = fit < 1 ? 1 : fit;
    final cap = maxCount;
    return cap != null && count > cap ? cap : count;
  }

  @override
  bool operator ==(Object other) =>
      other is MosaicMinExtentColumns &&
      other.minExtent == minExtent &&
      other.maxCount == maxCount;

  @override
  int get hashCode => Object.hash(minExtent, maxCount);

  @override
  String toString() =>
      'MosaicColumns.minExtent($minExtent, '
      'maxCount: $maxCount)';
}

/// Columns derived from a maximum tile extent. See [MosaicColumns.maxExtent].
final class MosaicMaxExtentColumns extends MosaicColumns {
  /// Creates columns that keep tiles at most [maxExtent] wide.
  const MosaicMaxExtentColumns(this.maxExtent) : assert(maxExtent > 0);

  /// The largest extent a tile may have.
  final double maxExtent;

  @override
  int resolve(double crossAxisExtent, double gap) {
    // The smallest n with n * maxExtent + (n - 1) * gap >= extent.
    final count = ((crossAxisExtent + gap) / (maxExtent + gap)).ceil();
    return count < 1 ? 1 : count;
  }

  @override
  bool operator ==(Object other) =>
      other is MosaicMaxExtentColumns && other.maxExtent == maxExtent;

  @override
  int get hashCode => maxExtent.hashCode;

  @override
  String toString() => 'MosaicColumns.maxExtent($maxExtent)';
}

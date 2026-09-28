import 'package:flutter/foundation.dart';

/// How a mosaic grid arranges its tiles along the main axis.
@immutable
sealed class MosaicLayout {
  const MosaicLayout();

  /// Tiles fill rows from the start edge; each row is as tall as its tallest
  /// tile, so tiles in the same row line up.
  ///
  /// [fit] decides what the shorter tiles in a row do with the spare room.
  /// A tile spanning more columns than are left in the current row moves to
  /// the next one.
  const factory MosaicLayout.rows({MosaicRowFit fit}) = MosaicRowsLayout;

  /// Every tile keeps its own height and drops into the column that ends
  /// first — the Pinterest-style arrangement.
  ///
  /// A tile spanning several columns takes the run of columns whose tallest
  /// column ends first, leftmost on ties.
  const factory MosaicLayout.masonry() = MosaicMasonryLayout;
}

/// Rows of aligned tiles. See [MosaicLayout.rows].
final class MosaicRowsLayout extends MosaicLayout {
  /// Creates a rows layout.
  const MosaicRowsLayout({this.fit = MosaicRowFit.stretch});

  /// What a tile shorter than its row does with the spare room.
  final MosaicRowFit fit;

  @override
  bool operator ==(Object other) =>
      other is MosaicRowsLayout && other.fit == fit;

  @override
  int get hashCode => fit.hashCode;

  @override
  String toString() => 'MosaicLayout.rows(fit: ${fit.name})';
}

/// Columns of free-height tiles. See [MosaicLayout.masonry].
final class MosaicMasonryLayout extends MosaicLayout {
  /// Creates a masonry layout.
  const MosaicMasonryLayout();

  @override
  bool operator ==(Object other) => other is MosaicMasonryLayout;

  @override
  int get hashCode => (MosaicMasonryLayout).hashCode;

  @override
  String toString() => 'MosaicLayout.masonry()';
}

/// What a tile shorter than its row does with the spare room, in
/// [MosaicLayout.rows].
enum MosaicRowFit {
  /// The tile grows to the height of the row, so every tile in a row has the
  /// same height. The usual choice for cards with a background or border.
  stretch,

  /// The tile keeps its height and sits at the start of the row.
  start,

  /// The tile keeps its height and sits in the middle of the row.
  center,

  /// The tile keeps its height and sits at the end of the row.
  end,
}

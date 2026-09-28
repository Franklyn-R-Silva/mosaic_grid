/// Lazy grids whose tiles size themselves.
///
/// * [MosaicGrid] — a scroll view with a header, a footer, end-of-list paging
///   and jump-to-item.
/// * [SliverMosaicGrid] — the same grid as a sliver, for a [CustomScrollView].
///
/// Tiles are laid out in aligned rows ([MosaicLayout.rows]) or masonry
/// columns ([MosaicLayout.masonry]), in a number of columns chosen by
/// [MosaicColumns], and may span several columns.
library;

import 'package:flutter/widgets.dart';

import 'src/mosaic_columns.dart';
import 'src/mosaic_layout.dart';
import 'src/widgets/mosaic_grid.dart';
import 'src/widgets/sliver_mosaic_grid.dart';

export 'src/mosaic_columns.dart';
export 'src/mosaic_layout.dart';
export 'src/rendering/render_sliver_mosaic.dart' show MosaicSpanCallback;
export 'src/widgets/mosaic_grid.dart';
export 'src/widgets/sliver_mosaic_grid.dart'
    show MosaicController, SliverMosaicGrid;

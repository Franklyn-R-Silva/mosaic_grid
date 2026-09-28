import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../mosaic_columns.dart';
import '../mosaic_layout.dart';
import '../rendering/mosaic_cell.dart';
import '../rendering/render_sliver_mosaic.dart';

/// A sliver that lays its children out as a mosaic grid, building them lazily
/// as they scroll into view.
///
/// Tiles either line up in rows ([MosaicLayout.rows], the default), each row as
/// tall as its tallest tile, or drop into the shortest column
/// ([MosaicLayout.masonry]). In both, a tile can span several columns through
/// [columnSpan].
///
/// Tiles are sized by their content: the grid gives each one its column width
/// and lets it choose its own height. There is no aspect ratio to tune and
/// nothing to cut off when a tile grows.
///
/// Use it inside a [CustomScrollView]. For a ready-made scroll view with a
/// header, a footer and end-of-list loading, see `MosaicGrid`.
class SliverMosaicGrid extends StatefulWidget {
  /// Creates a mosaic grid from an explicit list of [children].
  ///
  /// Every child is kept in memory, even while off screen; use
  /// [SliverMosaicGrid.builder] for long or unbounded lists.
  SliverMosaicGrid({
    super.key,
    required List<Widget> children,
    this.columns = const MosaicColumns.count(2),
    this.layout = const MosaicLayout.rows(),
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    this.columnSpan,
    this.controller,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(columnGap >= 0),
       assert(rowGap >= 0),
       itemCount = children.length,
       itemBuilder = ((BuildContext context, int index) => children[index]),
       findItemIndexCallback = ((Key key) {
         final index = children.indexWhere((Widget child) => child.key == key);
         return index < 0 ? null : index;
       });

  /// Creates a mosaic grid that builds its tiles on demand.
  ///
  /// [itemBuilder] is called only for the items near the viewport, with
  /// indices from 0 to [itemCount] - 1.
  const SliverMosaicGrid.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns = const MosaicColumns.count(2),
    this.layout = const MosaicLayout.rows(),
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    this.columnSpan,
    this.controller,
    this.findItemIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(itemCount >= 0),
       assert(columnGap >= 0),
       assert(rowGap >= 0);

  /// The number of items in the grid.
  final int itemCount;

  /// Builds the tile for an item.
  final IndexedWidgetBuilder itemBuilder;

  /// How many columns the grid has. Defaults to two.
  final MosaicColumns columns;

  /// How tiles are arranged along the main axis. Defaults to aligned rows.
  final MosaicLayout layout;

  /// The gap between neighbouring columns.
  final double columnGap;

  /// The gap between tiles along the main axis.
  final double rowGap;

  /// How many columns each item spans. Null means one column each.
  ///
  /// Called with item indices only, before the tile is built — decide the
  /// span from your data (`(i) => products[i].featured ? 2 : 1`).
  final MosaicSpanCallback? columnSpan;

  /// Scrolls the grid to a given item. See [MosaicController].
  final MosaicController? controller;

  /// Finds the current index of the tile whose widget has [Key] `key`, so the
  /// tile keeps its state when the items are reordered.
  final ChildIndexGetter? findItemIndexCallback;

  /// Whether to wrap each tile in an [AutomaticKeepAlive].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each tile in a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether to wrap each tile in an [IndexedSemantics].
  final bool addSemanticIndexes;

  @override
  State<SliverMosaicGrid> createState() => _SliverMosaicGridState();
}

class _SliverMosaicGridState extends State<SliverMosaicGrid> {
  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(SliverMosaicGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  RenderSliverMosaic? get _renderSliver {
    final renderObject = context.findRenderObject();
    return renderObject is RenderSliverMosaic ? renderObject : null;
  }

  Future<void> _reveal(
    int index, {
    required double alignment,
    Duration? duration,
    Curve curve = Curves.easeInOut,
  }) async {
    RangeError.checkValueInInterval(index, 0, widget.itemCount - 1, 'index');
    // The first move may land on an estimate — the grid only knows exact
    // positions for what it has measured — so check again once the viewport
    // has laid out there, and correct.
    for (var attempt = 0; attempt < 6; attempt++) {
      if (!mounted) {
        return;
      }
      final renderSliver = _renderSliver;
      final scrollable = Scrollable.maybeOf(context);
      if (renderSliver == null || scrollable == null) {
        return;
      }
      final location = await renderSliver.locate(index);
      if (location == null || !mounted) {
        return;
      }
      final position = scrollable.position;
      final target =
          (location.scrollOffset -
                  alignment * (position.viewportDimension - location.extent))
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - position.pixels).abs() < 0.5) {
        return;
      }
      if (duration != null && attempt == 0) {
        await position.animateTo(target, duration: duration, curve: curve);
      } else {
        position.jumpTo(target);
      }
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Widget _buildCell(BuildContext context, int index) {
    var child = widget.itemBuilder(context, index);
    final key = child.key;
    if (widget.addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (widget.addSemanticIndexes) {
      child = IndexedSemantics(index: index, child: child);
    }
    return MosaicCell(
      key: key == null ? null : _MosaicCellKey(key),
      child: child,
    );
  }

  int? _findIndex(Key key) {
    final find = widget.findItemIndexCallback;
    if (find == null || key is! _MosaicCellKey) {
      return null;
    }
    return find(key.value);
  }

  @override
  Widget build(BuildContext context) {
    return _SliverMosaic(
      delegate: SliverChildBuilderDelegate(
        _buildCell,
        childCount: widget.itemCount,
        findChildIndexCallback: widget.findItemIndexCallback == null
            ? null
            : _findIndex,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        // Both are added inside the cell, so the cell stays the sliver's
        // direct child.
        addRepaintBoundaries: false,
        addSemanticIndexes: false,
      ),
      columns: widget.columns,
      layout: widget.layout,
      columnGap: widget.columnGap,
      rowGap: widget.rowGap,
      itemCount: widget.itemCount,
      columnSpan: widget.columnSpan,
    );
  }
}

/// Scrolls a mosaic grid to one of its items.
///
/// Give it to a `SliverMosaicGrid` or `MosaicGrid`, then call [jumpToIndex] or
/// [animateToIndex]. The grid measures every item up to the target first, so
/// the item lands exactly where asked even if it was never on screen. A
/// controller drives one grid at a time.
class MosaicController {
  _SliverMosaicGridState? _state;

  /// Whether a grid is currently using this controller.
  bool get isAttached => _state != null;

  void _attach(_SliverMosaicGridState state) {
    assert(
      _state == null || _state == state,
      'A MosaicController can only drive one grid at a time.',
    );
    _state = state;
  }

  void _detach(_SliverMosaicGridState state) {
    if (_state == state) {
      _state = null;
    }
  }

  /// Scrolls, without animation, so item [index] is on screen.
  ///
  /// [alignment] places the item in the viewport: 0 at the leading edge, 1 at
  /// the trailing edge, 0.5 in the middle. Near the ends of the grid the
  /// scroll stops at the edge instead.
  ///
  /// Completes once the item is in place, or immediately when no grid is
  /// attached.
  Future<void> jumpToIndex(int index, {double alignment = 0.0}) {
    final state = _state;
    if (state == null) {
      return Future<void>.value();
    }
    return state._reveal(index, alignment: alignment);
  }

  /// Animates the grid so item [index] is on screen. See [jumpToIndex] for
  /// [alignment].
  ///
  /// If the target was far past anything the grid had measured, the first
  /// animation may stop short of an estimate and finish with a small jump.
  Future<void> animateToIndex(
    int index, {
    required Duration duration,
    Curve curve = Curves.easeInOut,
    double alignment = 0.0,
  }) {
    final state = _state;
    if (state == null) {
      return Future<void>.value();
    }
    return state._reveal(
      index,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }
}

class _MosaicCellKey extends ValueKey<Key> {
  const _MosaicCellKey(super.value);
}

class _SliverMosaic extends SliverMultiBoxAdaptorWidget {
  const _SliverMosaic({
    required super.delegate,
    required this.columns,
    required this.layout,
    required this.columnGap,
    required this.rowGap,
    required this.itemCount,
    required this.columnSpan,
  });

  final MosaicColumns columns;
  final MosaicLayout layout;
  final double columnGap;
  final double rowGap;
  final int itemCount;
  final MosaicSpanCallback? columnSpan;

  @override
  RenderSliverMosaic createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverMosaic(
      childManager: element,
      columns: columns,
      mosaicLayout: layout,
      columnGap: columnGap,
      rowGap: rowGap,
      itemCount: itemCount,
      columnSpan: columnSpan,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverMosaic renderObject,
  ) {
    renderObject
      ..columns = columns
      ..mosaicLayout = layout
      ..columnGap = columnGap
      ..rowGap = rowGap
      ..itemCount = itemCount
      ..columnSpan = columnSpan;
  }
}

/// Wraps each tile of a mosaic grid in a [RenderMosaicCell].
class MosaicCell extends SingleChildRenderObjectWidget {
  /// Creates a cell around [child].
  const MosaicCell({super.key, super.child});

  @override
  RenderMosaicCell createRenderObject(BuildContext context) =>
      RenderMosaicCell();
}

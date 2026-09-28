import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../mosaic_columns.dart';
import '../mosaic_layout.dart';
import '../rendering/render_sliver_mosaic.dart';
import 'sliver_mosaic_grid.dart';

/// A scrollable mosaic grid: tiles sized by their content, in aligned rows or
/// masonry columns, with optional multi-column tiles.
///
/// Around the grid it adds what a paged list usually needs:
///
/// * a [header] and a [footer], full width, scrolling with the tiles — the
///   footer is the natural home for a "loading more" or "try again" row;
/// * [onEndReached], called once the user scrolls within
///   [endReachedThreshold] of the end, at most once per [itemCount];
/// * a [controller] to jump or animate to any item by index.
///
/// {@tool snippet}
///
/// A product showcase: at least 380 pixels per card, at most three columns,
/// each row as tall as its tallest card, featured products two columns wide.
///
/// ```dart
/// MosaicGrid.builder(
///   columns: const MosaicColumns.minExtent(380, maxCount: 3),
///   columnGap: 8,
///   rowGap: 8,
///   itemCount: products.length,
///   columnSpan: (i) => products[i].featured ? 2 : 1,
///   itemBuilder: (context, i) => ProductCard(products[i]),
///   footer: hasMore ? const LoadingRow() : null,
///   onEndReached: loadNextPage,
/// )
/// ```
/// {@end-tool}
///
/// For a grid mixed with other slivers, use [SliverMosaicGrid] in a
/// [CustomScrollView] instead.
class MosaicGrid extends StatefulWidget {
  /// Creates a mosaic grid from an explicit list of [children].
  ///
  /// Every child is kept in memory, even while off screen; use
  /// [MosaicGrid.builder] for long or paged lists.
  MosaicGrid({
    super.key,
    required List<Widget> children,
    this.columns = const MosaicColumns.count(2),
    this.layout = const MosaicLayout.rows(),
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    this.columnSpan,
    this.header,
    this.footer,
    this.onEndReached,
    this.endReachedThreshold = 400.0,
    this.controller,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.keyboardDismissBehavior,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  }) : itemCount = children.length,
       itemBuilder = ((BuildContext context, int index) => children[index]),
       findItemIndexCallback = ((Key key) {
         final index = children.indexWhere((Widget child) => child.key == key);
         return index < 0 ? null : index;
       });

  /// Creates a mosaic grid that builds its tiles on demand.
  ///
  /// [itemBuilder] is called only for the items near the viewport, with
  /// indices from 0 to [itemCount] - 1.
  const MosaicGrid.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns = const MosaicColumns.count(2),
    this.layout = const MosaicLayout.rows(),
    this.columnGap = 0.0,
    this.rowGap = 0.0,
    this.columnSpan,
    this.header,
    this.footer,
    this.onEndReached,
    this.endReachedThreshold = 400.0,
    this.controller,
    this.findItemIndexCallback,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.keyboardDismissBehavior,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(itemCount >= 0);

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
  final MosaicSpanCallback? columnSpan;

  /// A full-width widget before the tiles, scrolling with them.
  final Widget? header;

  /// A full-width widget after the tiles, scrolling with them.
  final Widget? footer;

  /// Called when the user scrolls within [endReachedThreshold] of the end.
  ///
  /// Fires at most once for each value of [itemCount], so it does not repeat
  /// while a page is loading; once the new items arrive and [itemCount]
  /// changes, it can fire again. It never fires while the grid is empty — the
  /// first page is the app's to load.
  final VoidCallback? onEndReached;

  /// How close to the end, in logical pixels, [onEndReached] fires.
  final double endReachedThreshold;

  /// Scrolls the grid to a given item. See [MosaicController].
  final MosaicController? controller;

  /// Finds the current index of the tile whose widget has [Key] `key`, so the
  /// tile keeps its state when the items are reordered.
  final ChildIndexGetter? findItemIndexCallback;

  /// Controls the scroll position of the grid.
  final ScrollController? scrollController;

  /// The axis the grid scrolls along.
  final Axis scrollDirection;

  /// Whether the grid scrolls from the end towards the start.
  final bool reverse;

  /// Whether this is the primary scroll view. See [ScrollView.primary].
  final bool? primary;

  /// How the grid responds to user input.
  final ScrollPhysics? physics;

  /// Whether the grid sizes itself to its content along the main axis.
  ///
  /// Measuring a shrink-wrapped grid lays out every tile, so keep it for
  /// short grids.
  final bool shrinkWrap;

  /// Space around the header, tiles and footer. Defaults to the
  /// [MediaQuery] padding along the scroll direction, like [ListView].
  final EdgeInsetsGeometry? padding;

  /// Whether to wrap each tile in an [AutomaticKeepAlive].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each tile in a [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Whether to wrap each tile in an [IndexedSemantics].
  final bool addSemanticIndexes;

  /// How the grid dismisses the keyboard. See
  /// [ScrollView.keyboardDismissBehavior].
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  /// See [ScrollView.dragStartBehavior].
  final DragStartBehavior dragStartBehavior;

  /// See [ScrollView.restorationId].
  final String? restorationId;

  /// See [ScrollView.clipBehavior].
  final Clip clipBehavior;

  @override
  State<MosaicGrid> createState() => _MosaicGridState();
}

class _MosaicGridState extends State<MosaicGrid> {
  // The item count at which onEndReached last fired.
  int? _endReachedAt;

  bool _handleNotification(Notification notification) {
    final ScrollMetrics metrics;
    if (notification is ScrollUpdateNotification && notification.depth == 0) {
      metrics = notification.metrics;
    } else if (notification is ScrollMetricsNotification &&
        notification.depth == 0) {
      metrics = notification.metrics;
    } else {
      return false;
    }
    final onEndReached = widget.onEndReached;
    if (onEndReached == null ||
        widget.itemCount == 0 ||
        _endReachedAt == widget.itemCount) {
      return false;
    }
    if (metrics.extentAfter <= widget.endReachedThreshold) {
      _endReachedAt = widget.itemCount;
      onEndReached();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final grid = SliverMosaicGrid.builder(
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
      columns: widget.columns,
      layout: widget.layout,
      columnGap: widget.columnGap,
      rowGap: widget.rowGap,
      columnSpan: widget.columnSpan,
      controller: widget.controller,
      findItemIndexCallback: widget.findItemIndexCallback,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
    );
    final header = widget.header;
    final footer = widget.footer;
    Widget sliver = header == null && footer == null
        ? grid
        : SliverMainAxisGroup(
            slivers: <Widget>[
              if (header != null) SliverToBoxAdapter(child: header),
              grid,
              if (footer != null) SliverToBoxAdapter(child: footer),
            ],
          );

    var padding = widget.padding;
    if (padding == null) {
      // Like ListView: take the MediaQuery padding along the scroll axis, and
      // leave the cross-axis padding for the tiles to handle.
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        final horizontal = mediaQuery.padding.copyWith(top: 0.0, bottom: 0.0);
        final vertical = mediaQuery.padding.copyWith(left: 0.0, right: 0.0);
        final scrollsVertically = widget.scrollDirection == Axis.vertical;
        padding = scrollsVertically ? vertical : horizontal;
        sliver = MediaQuery(
          data: mediaQuery.copyWith(
            padding: scrollsVertically ? horizontal : vertical,
          ),
          child: sliver,
        );
      }
    }
    if (padding != null) {
      sliver = SliverPadding(padding: padding, sliver: sliver);
    }

    return NotificationListener<Notification>(
      onNotification: _handleNotification,
      child: CustomScrollView(
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: widget.scrollController,
        primary: widget.primary,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        semanticChildCount: widget.itemCount,
        dragStartBehavior: widget.dragStartBehavior,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        restorationId: widget.restorationId,
        clipBehavior: widget.clipBehavior,
        slivers: <Widget>[sliver],
      ),
    );
  }
}

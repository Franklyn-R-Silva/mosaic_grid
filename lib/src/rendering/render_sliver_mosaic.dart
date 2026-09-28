import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../mosaic_columns.dart';
import '../mosaic_layout.dart';
import 'mosaic_cell.dart';
import 'mosaic_ledger.dart';

/// Returns how many columns the item at [index] spans. Values below 1 count as
/// 1, values above the column count as the whole row.
typedef MosaicSpanCallback = int Function(int index);

/// Parent data for the children of [RenderSliverMosaic].
class MosaicParentData extends SliverMultiBoxAdaptorParentData {
  /// Distance from the cross-axis origin of the sliver to the child, in
  /// physical terms (left edge in a vertical grid, top edge in a horizontal
  /// one), whatever the text direction.
  double crossAxisOffset = 0.0;

  @override
  String toString() => 'crossAxisOffset=$crossAxisOffset; ${super.toString()}';
}

/// Where an item of a mosaic grid sits along the main axis.
@immutable
class MosaicItemLocation {
  /// Creates an item location.
  const MosaicItemLocation({
    required this.index,
    required this.offset,
    required this.extent,
    required this.precedingScrollExtent,
  });

  /// The index of the item.
  final int index;

  /// Where the item's slot starts, measured from the start of the grid.
  final double offset;

  /// The main-axis extent of the item's slot.
  final double extent;

  /// The scroll extent of everything before the grid in its scroll view.
  final double precedingScrollExtent;

  /// Where the item's slot starts, measured from the start of the scroll view.
  double get scrollOffset => precedingScrollExtent + offset;

  @override
  String toString() =>
      'MosaicItemLocation(#$index, offset: $offset, '
      'extent: $extent, preceding: $precedingScrollExtent)';
}

/// A sliver that lays its box children out as a mosaic grid: aligned rows or
/// masonry columns, with tiles that may span several columns.
///
/// Children are created lazily, as they scroll into the cache extent. Their
/// positions come from a [MosaicLedger], which records items in index order
/// from the first one, so every position the grid has computed is exact.
///
/// Every child must be a [RenderMosaicCell]; the widget layer wraps each tile
/// in one.
class RenderSliverMosaic extends RenderSliverMultiBoxAdaptor {
  /// Creates a mosaic sliver.
  RenderSliverMosaic({
    required super.childManager,
    required MosaicColumns columns,
    required MosaicLayout mosaicLayout,
    required double columnGap,
    required double rowGap,
    required int itemCount,
    MosaicSpanCallback? columnSpan,
  }) : assert(columnGap >= 0),
       assert(rowGap >= 0),
       assert(itemCount >= 0),
       _columns = columns,
       _layout = mosaicLayout,
       _columnGap = columnGap,
       _rowGap = rowGap,
       _itemCount = itemCount,
       _columnSpan = columnSpan;

  /// How many columns the cross axis is split into.
  MosaicColumns get columns => _columns;
  MosaicColumns _columns;
  set columns(MosaicColumns value) {
    if (value == _columns) {
      return;
    }
    _columns = value;
    markNeedsLayout();
  }

  /// How tiles are arranged along the main axis.
  MosaicLayout get mosaicLayout => _layout;
  MosaicLayout _layout;
  set mosaicLayout(MosaicLayout value) {
    if (value == _layout) {
      return;
    }
    _layout = value;
    markNeedsLayout();
  }

  /// The gap between neighbouring columns.
  double get columnGap => _columnGap;
  double _columnGap;
  set columnGap(double value) {
    assert(value >= 0);
    if (value == _columnGap) {
      return;
    }
    _columnGap = value;
    markNeedsLayout();
  }

  /// The gap between tiles along the main axis.
  double get rowGap => _rowGap;
  double _rowGap;
  set rowGap(double value) {
    assert(value >= 0);
    if (value == _rowGap) {
      return;
    }
    _rowGap = value;
    markNeedsLayout();
  }

  /// The number of items in the grid.
  int get itemCount => _itemCount;
  int _itemCount;
  set itemCount(int value) {
    assert(value >= 0);
    if (value == _itemCount) {
      return;
    }
    _itemCount = value;
    markNeedsLayout();
  }

  /// How many columns each item spans. Null means one column each.
  MosaicSpanCallback? get columnSpan => _columnSpan;
  MosaicSpanCallback? _columnSpan;
  set columnSpan(MosaicSpanCallback? value) {
    if (identical(value, _columnSpan)) {
      return;
    }
    _columnSpan = value;
    markNeedsLayout();
  }

  // How many layout passes one performLayout may spend reconciling tiles whose
  // size changed. Each pass settles every change it saw, so more than two is
  // only needed by content that keeps resizing itself.
  static const int _maxPasses = 4;

  // How many items past the cache extent may be kept alive while measuring
  // ahead for [locate]. Past that, the grid stops holding on to children and
  // measures them one at a time.
  static const int _maxOvershoot = 32;

  // How long one layout may spend measuring items. Items are measured in index
  // order, so a jump far past what the grid has measured — a scrollbar drag, a
  // direct jumpTo, a locate — would otherwise measure everything in between in
  // a single frame. Past the budget the rest is measured over the next frames
  // and fills in as it arrives; the app never freezes.
  static const Duration _measureBudget = Duration(milliseconds: 12);

  // Items measured per layout whatever the budget, so slow tiles still move.
  static const int _minMeasuredPerLayout = 32;

  MosaicLedger? _ledger;

  // Per-layout state.
  double _stride = 0.0;
  int _count = 0;
  final Stopwatch _layoutClock = Stopwatch();
  int _measuredThisLayout = 0;
  bool _measureDeferred = false;
  bool _relayoutScheduled = false;

  bool get _overBudget =>
      _measuredThisLayout >= _minMeasuredPerLayout &&
      _layoutClock.elapsed > _measureBudget;

  int? _locateIndex;
  Completer<MosaicItemLocation?>? _locateCompleter;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MosaicParentData) {
      child.parentData = MosaicParentData();
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) =>
      (child.parentData! as MosaicParentData).crossAxisOffset;

  /// Measures the grid up to item [index] and reports where that item sits.
  ///
  /// Completes after the next layout, with null if the item does not exist or
  /// the grid is detached before it gets there. Items far past what the grid
  /// has already placed are measured over several frames, a bounded number
  /// per frame. A newer call replaces a pending one, which completes with
  /// null.
  Future<MosaicItemLocation?> locate(int index) {
    assert(index >= 0);
    if (!attached) {
      return SynchronousFuture<MosaicItemLocation?>(null);
    }
    _finishLocate(null);
    final completer = Completer<MosaicItemLocation?>();
    _locateCompleter = completer;
    _locateIndex = index;
    markNeedsLayout();
    return completer.future;
  }

  void _finishLocate(MosaicItemLocation? location) {
    final completer = _locateCompleter;
    _locateCompleter = null;
    _locateIndex = null;
    completer?.complete(location);
  }

  @override
  void detach() {
    _finishLocate(null);
    super.detach();
  }

  bool get _stretches =>
      _layout is MosaicRowsLayout &&
      (_layout as MosaicRowsLayout).fit == MosaicRowFit.stretch;

  double get _fitFactor => switch (_layout) {
    MosaicRowsLayout(fit: MosaicRowFit.center) => 0.5,
    MosaicRowsLayout(fit: MosaicRowFit.end) => 1.0,
    _ => 0.0,
  };

  int _spanOf(int index) => _columnSpan?.call(index) ?? 1;

  double _crossExtentOf(int span) => math.max(0.0, span * _stride - _columnGap);

  double _crossOffsetOf(int column, int span) {
    final start = column * _stride;
    return axisDirectionIsReversed(constraints.crossAxisDirection)
        ? constraints.crossAxisExtent - start - _crossExtentOf(span)
        : start;
  }

  MosaicCellConstraints _cellConstraints(int span, {double? stretchTo}) =>
      MosaicCellConstraints(
        axis: constraints.axis,
        crossAxisExtent: _crossExtentOf(span),
        stretchTo: stretchTo,
      );

  MosaicCellConstraints _placedConstraints(MosaicLedger ledger, int index) =>
      _cellConstraints(
        ledger.spanOf(index),
        stretchTo: _stretches ? ledger.slotExtent(index) : null,
      );

  double _naturalOf(RenderBox child) {
    assert(
      child is RenderMosaicCell,
      'RenderSliverMosaic children must be RenderMosaicCell; '
      'got ${child.runtimeType}.',
    );
    return child is RenderMosaicCell
        ? child.naturalExtent
        : paintExtentOf(child);
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);
    _layoutClock
      ..reset()
      ..start();
    _measuredThisLayout = 0;
    _measureDeferred = false;

    final columnCount = _columns.resolve(
      constraints.crossAxisExtent,
      _columnGap,
    );
    _stride = (constraints.crossAxisExtent + _columnGap) / columnCount;
    _count = _itemCount;

    if (_count == 0) {
      _ledger = null;
      collectGarbage(childCount, 0);
      geometry = SliverGeometry.zero;
      childManager.setDidUnderflow(true);
      _finishLocate(null);
      childManager.didFinishLayout();
      return;
    }

    final start = constraints.scrollOffset + constraints.cacheOrigin;
    final end = start + constraints.remainingCacheExtent;

    var ledger = _ledger;
    if (ledger == null ||
        ledger.columnCount != columnCount ||
        ledger.rowGap != _rowGap ||
        !ledger.matches(_layout)) {
      // The old placement no longer applies. Place everything again, keeping
      // the item at the top of the viewport where it was.
      final previous = ledger;
      final anchor = previous == null ? null : _findAnchor(previous);
      ledger = _ledger = MosaicLedger.forLayout(
        _layout,
        columnCount: columnCount,
        rowGap: _rowGap,
      );
      if (anchor != null) {
        _fill(ledger, start, end, mustCommit: anchor.index);
        final correction = _anchorCorrection(ledger, anchor);
        if (correction != null) {
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          childManager.didFinishLayout();
          return;
        }
      }
    }

    if (ledger.measuredCount > _count) {
      ledger.truncate(_count);
    } else if (ledger.measuredCount < _count) {
      ledger.reopenTail();
    }

    _Anchor? anchor;
    var passes = 0;
    while (true) {
      _fill(
        ledger,
        start,
        end,
        mustCommit: anchor?.index ?? -1,
        budgetedTarget: _locateIndex ?? -1,
      );
      if (anchor != null) {
        final correction = _anchorCorrection(ledger, anchor);
        anchor = null;
        if (correction != null) {
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          childManager.didFinishLayout();
          return;
        }
      }
      final changedFrom = _place(ledger, start, end);
      passes += 1;
      if (changedFrom == null || passes >= _maxPasses) {
        break;
      }
      // Some tile changed size (or span) since it was measured: everything
      // from it on moves. Remember what the user is looking at so it stays put.
      anchor = _findAnchor(ledger);
      ledger.truncate(changedFrom);
    }

    _settleLocate(ledger);
    if (_measureDeferred) {
      _continueNextFrame();
    }

    var leading = double.infinity;
    var trailing = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final index = indexOf(child);
      if (index >= ledger.committedCount) {
        continue;
      }
      final offset = ledger.slotOffset(index);
      leading = math.min(leading, offset);
      trailing = math.max(trailing, offset + ledger.slotExtent(index));
    }
    final complete = ledger.committedCount >= _count;
    final scrollExtent = complete
        ? ledger.contentExtent
        : math.max(_estimateExtent(ledger), trailing);

    if (leading == double.infinity) {
      geometry = SliverGeometry(
        scrollExtent: scrollExtent,
        maxPaintExtent: scrollExtent,
        hasVisualOverflow: true,
      );
    } else {
      final paintExtent = calculatePaintOffset(
        constraints,
        from: leading,
        to: trailing,
      );
      final cacheExtent = calculateCacheOffset(
        constraints,
        from: leading,
        to: trailing,
      );
      geometry = SliverGeometry(
        scrollExtent: scrollExtent,
        paintExtent: paintExtent,
        cacheExtent: cacheExtent,
        maxPaintExtent: scrollExtent,
        hasVisualOverflow:
            trailing >
                constraints.scrollOffset + constraints.remainingPaintExtent ||
            constraints.scrollOffset > 0.0,
      );
    }

    if (complete && lastChild != null && indexOf(lastChild!) == _count - 1) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }

  // Extrapolates the extent of the whole grid from the items placed so far.
  double _estimateExtent(MosaicLedger ledger) {
    final committed = ledger.committedCount;
    if (committed == 0) {
      return 0.0;
    }
    final perItem = (ledger.contentExtent + _rowGap) / committed;
    return ledger.contentExtent + perItem * (_count - committed);
  }

  /// Measures items in index order until item [mustCommit] is committed and —
  /// within the per-layout budget — the ledger covers `[start, end]` and item
  /// [budgetedTarget] is committed. Whatever the budget leaves out is
  /// measured on the next frames.
  void _fill(
    MosaicLedger ledger,
    double start,
    double end, {
    int mustCommit = -1,
    int budgetedTarget = -1,
  }) {
    var overshoot = 0;
    var sliding = false;

    // Needed in this frame whatever it costs: one placed item to estimate the
    // extent from, and the anchor that keeps the view still.
    bool needsNow() =>
        ledger.committedCount == 0 || ledger.committedCount <= mustCommit;
    bool needsBand() => ledger.coveredUntil < end;
    bool needsTarget() => ledger.committedCount <= budgetedTarget;
    bool needsMore() => needsNow() || needsBand() || needsTarget();

    while (needsMore()) {
      final index = ledger.measuredCount;
      if (index >= _count) {
        break;
      }
      if (!needsNow() && _overBudget) {
        _measureDeferred = true;
        break;
      }
      final span = ledger.clampSpan(_spanOf(index));
      ledger.prepare(span);
      if (!needsMore()) {
        // Closing the open row was all that was missing.
        break;
      }
      final natural = _measure(index, span);
      if (natural == null) {
        _count = index;
        break;
      }
      ledger.add(span, natural);
      _measuredThisLayout += 1;

      _releaseLeading(ledger, start);
      if (_measuredStart(ledger, index) >= end) {
        overshoot += 1;
        if (sliding || overshoot > _maxOvershoot) {
          // Far past the band, on the way to a located item: stop keeping
          // children alive, measure each one and let it go.
          sliding = true;
          collectGarbage(childCount, 0);
        }
      } else {
        overshoot = 0;
      }
    }
    if (ledger.measuredCount >= _count) {
      ledger.close();
    }
  }

  // Where a measured item starts: its slot if committed, else the open row.
  double _measuredStart(MosaicLedger ledger, int index) =>
      index < ledger.committedCount
      ? ledger.slotOffset(index)
      : ledger.coveredUntil;

  // Drops children at the head of the list that end before [start]: no window
  // at this scroll offset needs them.
  void _releaseLeading(MosaicLedger ledger, double start) {
    var leading = 0;
    var child = firstChild;
    while (child != null && child != lastChild) {
      final index = indexOf(child);
      if (index >= ledger.committedCount ||
          ledger.slotOffset(index) + ledger.slotExtent(index) >= start) {
        break;
      }
      leading += 1;
      child = childAfter(child);
    }
    if (leading > 0) {
      collectGarbage(leading, 0);
    }
  }

  RenderBox? _childAt(int index) {
    var child = firstChild;
    while (child != null && indexOf(child) < index) {
      child = childAfter(child);
    }
    return child != null && indexOf(child) == index ? child : null;
  }

  /// Lays out item [index] with a free main axis and returns its natural
  /// extent, creating the child if needed. Returns null if there is no such
  /// item.
  double? _measure(int index, int span) {
    final childConstraints = _cellConstraints(span);
    var child = _childAt(index);
    if (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
    } else if (lastChild != null && indexOf(lastChild!) == index - 1) {
      child = insertAndLayoutChild(
        childConstraints,
        after: lastChild,
        parentUsesSize: true,
      );
    } else {
      // Not adjacent to the live children: start a fresh run at [index].
      if (firstChild != null) {
        collectGarbage(childCount, 0);
      }
      if (addInitialChild(index: index)) {
        child = firstChild!..layout(childConstraints, parentUsesSize: true);
      }
    }
    return child == null ? null : _naturalOf(child);
  }

  /// Makes the live children exactly the committed items that meet
  /// `[start, end]`, lays each out in its slot and positions it.
  ///
  /// Returns the first index whose natural extent or span no longer matches
  /// the ledger, or null if everything matched.
  int? _place(MosaicLedger ledger, double start, double end) {
    final window = ledger.window(start, end);
    if (window == null) {
      if (childCount > 0) {
        collectGarbage(childCount, 0);
      }
      return null;
    }
    final (first, last) = window;

    if (firstChild != null) {
      collectGarbage(
        calculateLeadingGarbage(firstIndex: first),
        calculateTrailingGarbage(lastIndex: last),
      );
    }
    if (firstChild == null && !addInitialChild(index: first)) {
      // The list is shorter than the ledger thought.
      _count = first;
      ledger.truncate(first);
      return first;
    }
    while (indexOf(firstChild!) > first) {
      final index = indexOf(firstChild!) - 1;
      final inserted = insertAndLayoutLeadingChild(
        _placedConstraints(ledger, index),
        parentUsesSize: true,
      );
      if (inserted == null) {
        break;
      }
    }

    int? changed;
    var child = firstChild!;
    var index = indexOf(child);
    while (true) {
      child.layout(_placedConstraints(ledger, index), parentUsesSize: true);
      if (_position(ledger, child, index)) {
        changed ??= index;
      }
      if (index >= last) {
        break;
      }
      var next = childAfter(child);
      if (next == null || indexOf(next) != index + 1) {
        next = insertAndLayoutChild(
          _placedConstraints(ledger, index + 1),
          after: child,
          parentUsesSize: true,
        );
        if (next == null) {
          _count = index + 1;
          ledger.truncate(_count);
          return changed ?? _count;
        }
      }
      child = next;
      index += 1;
    }
    return changed;
  }

  /// Positions [child] in the slot of item [index]. Returns whether the child
  /// no longer matches what the ledger recorded for it.
  bool _position(MosaicLedger ledger, RenderBox child, int index) {
    final parentData = child.parentData! as MosaicParentData;
    final slotExtent = ledger.slotExtent(index);
    final spare = math.max(0.0, slotExtent - paintExtentOf(child));
    parentData.layoutOffset = ledger.slotOffset(index) + spare * _fitFactor;
    parentData.crossAxisOffset = _crossOffsetOf(
      ledger.columnOf(index),
      ledger.spanOf(index),
    );
    return (_naturalOf(child) - ledger.naturalExtent(index)).abs() >
            precisionErrorTolerance ||
        ledger.clampSpan(_spanOf(index)) != ledger.spanOf(index);
  }

  // The first live item still visible at the leading edge of the viewport.
  _Anchor? _findAnchor(MosaicLedger ledger) {
    final scrollOffset = constraints.scrollOffset;
    if (scrollOffset <= 0.0) {
      return null;
    }
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final index = indexOf(child);
      if (index >= ledger.committedCount) {
        continue;
      }
      final offset = ledger.slotOffset(index);
      if (offset + ledger.slotExtent(index) > scrollOffset) {
        return _Anchor(index, offset);
      }
    }
    return null;
  }

  // How far to scroll so that [anchor] ends up where it was on screen.
  double? _anchorCorrection(MosaicLedger ledger, _Anchor anchor) {
    if (anchor.index >= ledger.committedCount) {
      return null;
    }
    final delta = ledger.slotOffset(anchor.index) - anchor.offset;
    if (delta.abs() <= precisionErrorTolerance) {
      return null;
    }
    return math.max(delta, -constraints.scrollOffset);
  }

  void _settleLocate(MosaicLedger ledger) {
    final target = _locateIndex;
    if (target == null) {
      return;
    }
    if (target >= _count) {
      _finishLocate(null);
      return;
    }
    if (target < ledger.committedCount) {
      _finishLocate(
        MosaicItemLocation(
          index: target,
          offset: ledger.slotOffset(target),
          extent: ledger.slotExtent(target),
          precedingScrollExtent: constraints.precedingScrollExtent,
        ),
      );
      return;
    }
    // Still on the way there: carry on next frame.
    _continueNextFrame();
  }

  // Lays out again after this frame, to carry on measuring.
  void _continueNextFrame() {
    if (_relayoutScheduled) {
      return;
    }
    _relayoutScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _relayoutScheduled = false;
      if (attached) {
        markNeedsLayout();
      }
    });
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<MosaicColumns>('columns', _columns))
      ..add(DiagnosticsProperty<MosaicLayout>('layout', _layout))
      ..add(DoubleProperty('columnGap', _columnGap))
      ..add(DoubleProperty('rowGap', _rowGap))
      ..add(IntProperty('itemCount', _itemCount))
      ..add(IntProperty('placed', _ledger?.committedCount));
  }
}

class _Anchor {
  const _Anchor(this.index, this.offset);

  final int index;
  final double offset;
}

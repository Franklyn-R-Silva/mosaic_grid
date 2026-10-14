import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// The constraints a mosaic grid hands each of its cells: a fixed extent on the
/// cross axis, a free one on the main axis, and optionally a main-axis extent
/// the cell should stretch its child to.
///
/// [stretchTo] travels inside the constraints on purpose. Constraints are what
/// the framework compares to decide whether a render object needs to lay out
/// again, so a cell whose row height did not change is skipped entirely while
/// the grid scrolls — no measuring pass, no second layout.
@immutable
class MosaicCellConstraints extends BoxConstraints {
  /// Creates cell constraints for a grid scrolling along [axis].
  const MosaicCellConstraints({
    required this.axis,
    required double crossAxisExtent,
    this.stretchTo,
  }) : super(
         minWidth: axis == Axis.vertical ? crossAxisExtent : 0.0,
         maxWidth: axis == Axis.vertical ? crossAxisExtent : double.infinity,
         minHeight: axis == Axis.vertical ? 0.0 : crossAxisExtent,
         maxHeight: axis == Axis.vertical ? double.infinity : crossAxisExtent,
       );

  /// The axis the grid scrolls along.
  final Axis axis;

  /// The main-axis extent to stretch the child to, if it is naturally shorter.
  final double? stretchTo;

  /// The same limits as plain [BoxConstraints], which is what the cell passes
  /// on to its child: the child does not need to know about stretching.
  BoxConstraints get asBoxConstraints => BoxConstraints(
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is MosaicCellConstraints &&
      super == other &&
      other.axis == axis &&
      other.stretchTo == stretchTo;

  @override
  int get hashCode => Object.hash(super.hashCode, axis, stretchTo);

  @override
  String toString() =>
      'MosaicCellConstraints(${super.toString()}, stretchTo: $stretchTo)';
}

/// The render object wrapped around every tile of a mosaic grid.
///
/// It lays its child out with a free main axis first, so it always knows the
/// child's natural extent — the number the grid places tiles with. When the
/// constraints ask for more room than that, it lays the child out a second
/// time, at least [MosaicCellConstraints.stretchTo] long.
///
/// Both passes only run when the cell itself has to lay out: when its child
/// changed, or its row changed height. Scrolling never triggers them.
class RenderMosaicCell extends RenderProxyBox {
  /// Creates a cell around [child].
  RenderMosaicCell({RenderBox? child}) : super(child);

  /// The main-axis extent the child wants when it is not stretched, from the
  /// last layout.
  double get naturalExtent => _naturalExtent;
  double _naturalExtent = 0.0;

  @override
  void performLayout() {
    final incoming = constraints;
    final Axis axis;
    final double? stretchTo;
    final BoxConstraints base;
    if (incoming is MosaicCellConstraints) {
      axis = incoming.axis;
      stretchTo = incoming.stretchTo;
      base = incoming.asBoxConstraints;
    } else {
      axis = Axis.vertical;
      stretchTo = null;
      base = incoming;
    }

    final child = this.child;
    if (child == null) {
      _naturalExtent = 0.0;
      final extent = stretchTo ?? 0.0;
      size = base.constrain(
        axis == Axis.vertical ? Size(0.0, extent) : Size(extent, 0.0),
      );
      return;
    }

    child.layout(base, parentUsesSize: true);
    _naturalExtent = _mainExtent(child.size, axis);
    if (stretchTo != null && stretchTo > _naturalExtent) {
      // At least the row's extent rather than exactly it: a child laid out
      // with tight constraints becomes a relayout boundary, and a stretched
      // tile that later grows — a section that expands, an image that loads —
      // would never reach this cell, so its row would never grow. Every child
      // already lays out with a free main axis in the first pass, so a lower
      // bound alone is safe for it.
      final atLeast = axis == Axis.vertical
          ? base.copyWith(minHeight: stretchTo)
          : base.copyWith(minWidth: stretchTo);
      child.layout(atLeast, parentUsesSize: true);
      if (_mainExtent(child.size, axis) > stretchTo + precisionErrorTolerance) {
        // It took the extra room and then some: hold it to the row.
        final tight = axis == Axis.vertical
            ? base.copyWith(minHeight: stretchTo, maxHeight: stretchTo)
            : base.copyWith(minWidth: stretchTo, maxWidth: stretchTo);
        child.layout(tight, parentUsesSize: true);
      }
    }
    size = base.constrain(child.size);
  }

  static double _mainExtent(Size size, Axis axis) =>
      axis == Axis.vertical ? size.height : size.width;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('naturalExtent', _naturalExtent));
  }
}

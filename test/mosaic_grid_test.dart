import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:mosaic_grid/src/rendering/mosaic_ledger.dart';

Widget harness(
  Widget child, {
  double width = 300,
  double height = 600,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

Widget box(int index, double extent, {Axis axis = Axis.vertical}) {
  return SizedBox(
    key: ValueKey<int>(index),
    width: axis == Axis.horizontal ? extent : null,
    height: axis == Axis.vertical ? extent : null,
  );
}

Rect rectOf(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey<int>(index)));

bool isBuilt(int index) =>
    find.byKey(ValueKey<int>(index)).evaluate().isNotEmpty;

double varied(int index) => 40.0 + (index * 37) % 90;

Matcher rectCloseTo(Rect expected) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(expected.left, 1e-6))
    .having((r) => r.top, 'top', closeTo(expected.top, 1e-6))
    .having((r) => r.width, 'width', closeTo(expected.width, 1e-6))
    .having((r) => r.height, 'height', closeTo(expected.height, 1e-6));

void main() {
  group('rows', () {
    testWidgets('each row is as tall as its tallest tile', (tester) async {
      const extents = [50.0, 80.0, 30.0, 40.0, 40.0, 40.0, 10.0];
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            rowGap: 10,
            itemCount: extents.length,
            itemBuilder: (_, i) => box(i, extents[i]),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 100, 80));
      expect(rectOf(tester, 1), const Rect.fromLTWH(100, 0, 100, 80));
      expect(rectOf(tester, 2), const Rect.fromLTWH(200, 0, 100, 80));
      expect(rectOf(tester, 3), const Rect.fromLTWH(0, 90, 100, 40));
      expect(rectOf(tester, 6), const Rect.fromLTWH(0, 140, 100, 10));
    });

    testWidgets('column gaps split the cross axis evenly', (tester) async {
      await tester.pumpWidget(
        harness(
          width: 320,
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            columnGap: 10,
            itemCount: 3,
            itemBuilder: (_, i) => box(i, 20),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 100, 20));
      expect(rectOf(tester, 1), const Rect.fromLTWH(110, 0, 100, 20));
      expect(rectOf(tester, 2), const Rect.fromLTWH(220, 0, 100, 20));
    });

    testWidgets('fit places shorter tiles inside their row', (tester) async {
      Future<void> pumpFit(MosaicRowFit fit) => tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            layout: MosaicLayout.rows(fit: fit),
            itemCount: 2,
            itemBuilder: (_, i) => box(i, i == 0 ? 20 : 60),
          ),
        ),
      );
      await pumpFit(MosaicRowFit.start);
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 150, 20));
      await pumpFit(MosaicRowFit.center);
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 20, 150, 20));
      await pumpFit(MosaicRowFit.end);
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 40, 150, 20));
      await pumpFit(MosaicRowFit.stretch);
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 150, 60));
    });

    testWidgets('a spanning tile that does not fit starts a new row', (
      tester,
    ) async {
      const spans = [1, 2, 2, 1];
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            itemCount: spans.length,
            columnSpan: (i) => spans[i],
            itemBuilder: (_, i) => box(i, 10),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 100, 10));
      expect(rectOf(tester, 1), const Rect.fromLTWH(100, 0, 200, 10));
      expect(rectOf(tester, 2), const Rect.fromLTWH(0, 10, 200, 10));
      expect(rectOf(tester, 3), const Rect.fromLTWH(200, 10, 100, 10));
    });

    testWidgets('right-to-left starts from the right edge', (tester) async {
      await tester.pumpWidget(
        harness(
          textDirection: TextDirection.rtl,
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            itemCount: 4,
            columnSpan: (i) => i == 3 ? 2 : 1,
            itemBuilder: (_, i) => box(i, 10),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(200, 0, 100, 10));
      expect(rectOf(tester, 2), const Rect.fromLTWH(0, 0, 100, 10));
      expect(rectOf(tester, 3), const Rect.fromLTWH(100, 10, 200, 10));
    });

    testWidgets('scrolls horizontally', (tester) async {
      const extents = [50.0, 80.0, 30.0, 40.0];
      await tester.pumpWidget(
        harness(
          width: 600,
          height: 300,
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            columns: const MosaicColumns.count(3),
            rowGap: 10,
            itemCount: extents.length,
            itemBuilder: (_, i) => box(i, extents[i], axis: Axis.horizontal),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 80, 100));
      expect(rectOf(tester, 2), const Rect.fromLTWH(0, 200, 80, 100));
      expect(rectOf(tester, 3), const Rect.fromLTWH(90, 0, 40, 100));
    });

    testWidgets('a tile that grows makes its row grow', (tester) async {
      final tall = ValueNotifier<bool>(false);
      addTearDown(tall.dispose);
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            rowGap: 10,
            itemCount: 6,
            itemBuilder: (_, i) => i == 1
                ? ValueListenableBuilder<bool>(
                    valueListenable: tall,
                    builder: (_, value, __) => box(i, value ? 120 : 30),
                  )
                : box(i, 30),
          ),
        ),
      );
      expect(rectOf(tester, 3).top, 40);

      tall.value = true;
      await tester.pump();
      expect(rectOf(tester, 0).height, 120);
      expect(rectOf(tester, 3).top, 130);

      tall.value = false;
      await tester.pump();
      expect(rectOf(tester, 0).height, 30);
      expect(rectOf(tester, 3).top, 40);
    });

    testWidgets('items added later join the last row', (tester) async {
      Future<void> pumpCount(int count) => tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            columns: const MosaicColumns.count(3),
            itemCount: count,
            itemBuilder: (_, i) => box(i, 10),
          ),
        ),
      );
      await pumpCount(4);
      expect(rectOf(tester, 3), const Rect.fromLTWH(0, 10, 100, 10));
      await pumpCount(6);
      expect(rectOf(tester, 4), const Rect.fromLTWH(100, 10, 100, 10));
      expect(rectOf(tester, 5), const Rect.fromLTWH(200, 10, 100, 10));
      await pumpCount(2);
      expect(isBuilt(2), isFalse);
      expect(rectOf(tester, 1), const Rect.fromLTWH(100, 0, 100, 10));
    });

    testWidgets('scrolling does not lay tiles out again', (tester) async {
      final layouts = <int, int>{};
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            columns: const MosaicColumns.count(3),
            itemCount: 300,
            itemBuilder: (_, i) => _CountLayouts(
              onLayout: () => layouts[i] = (layouts[i] ?? 0) + 1,
              child: box(i, varied(i)),
            ),
          ),
        ),
      );
      final before = Map<int, int>.of(layouts);
      controller.jumpTo(40);
      await tester.pump();
      controller.jumpTo(80);
      await tester.pump();
      for (final entry in before.entries) {
        if (isBuilt(entry.key)) {
          expect(layouts[entry.key], entry.value, reason: 'item ${entry.key}');
        }
      }
    });
  });

  group('masonry', () {
    testWidgets('each tile drops into the shortest column', (tester) async {
      const extents = [100.0, 50.0, 30.0, 80.0];
      await tester.pumpWidget(
        harness(
          width: 200,
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            layout: const MosaicLayout.masonry(),
            itemCount: extents.length,
            itemBuilder: (_, i) => box(i, extents[i]),
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 100, 100));
      expect(rectOf(tester, 1), const Rect.fromLTWH(100, 0, 100, 50));
      expect(rectOf(tester, 2), const Rect.fromLTWH(100, 50, 100, 30));
      expect(rectOf(tester, 3), const Rect.fromLTWH(100, 80, 100, 80));
    });

    testWidgets('builds lazily and scrolls back to exact positions', (
      tester,
    ) async {
      const count = 2000;
      final built = <int>{};
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            layout: const MosaicLayout.masonry(),
            columns: const MosaicColumns.count(3),
            columnGap: 8,
            rowGap: 8,
            itemCount: count,
            columnSpan: (i) => i % 17 == 0 ? 2 : 1,
            itemBuilder: (_, i) {
              built.add(i);
              return box(i, varied(i));
            },
          ),
        ),
      );
      expect(built.length, lessThan(80));

      final model = MasonryLedger(columnCount: 3, rowGap: 8);
      for (var i = 0; i < count; i++) {
        model.add(i % 17 == 0 ? 2 : 1, varied(i));
      }
      const stride = (300 + 8) / 3;
      void expectMatchesModel(double scrollOffset) {
        var checked = 0;
        for (var i = 0; i < count; i++) {
          if (!isBuilt(i)) {
            continue;
          }
          final span = model.spanOf(i);
          expect(
            rectOf(tester, i),
            rectCloseTo(
              Rect.fromLTWH(
                model.columnOf(i) * stride,
                model.slotOffset(i) - scrollOffset,
                span * stride - 8,
                varied(i),
              ),
            ),
            reason: 'item $i at $scrollOffset',
          );
          checked += 1;
        }
        expect(checked, greaterThan(0));
      }

      expectMatchesModel(0);
      for (final offset in [3000.0, 15000.0, 7000.0, 120.0, 0.0]) {
        controller.jumpTo(offset);
        // A long jump may take a few frames to measure its way there.
        await tester.pumpAndSettle();
        expectMatchesModel(controller.offset);
      }
    });

    testWidgets('a long jump is measured over frames, not in one', (
      tester,
    ) async {
      const count = 20000;
      var builtThisFrame = 0;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            layout: const MosaicLayout.masonry(),
            columns: const MosaicColumns.count(3),
            itemCount: count,
            itemBuilder: (_, i) {
              builtThisFrame += 1;
              return box(i, varied(i));
            },
          ),
        ),
      );

      builtThisFrame = 0;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      // Reaching the end measures ~20k items; one frame only takes a slice.
      expect(builtThisFrame, lessThan(count ~/ 2));

      // The rest fills in over the next frames, at exact positions.
      await tester.pumpAndSettle();
      final model = MasonryLedger(columnCount: 3, rowGap: 0);
      for (var i = 0; i < count; i++) {
        model.add(1, varied(i));
      }
      void expectExact() {
        var checked = 0;
        for (var i = count - 1; i >= 0 && checked < 40; i--) {
          if (isBuilt(i)) {
            expect(
              rectOf(tester, i).top,
              closeTo(model.slotOffset(i) - controller.offset, 1e-6),
              reason: 'item $i',
            );
            checked += 1;
          }
        }
        expect(checked, greaterThan(0));
      }

      expectExact();
      // The first jump aimed at an estimate; now that everything is measured
      // the end is exact.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(isBuilt(count - 1), isTrue);
      expectExact();
    });

    testWidgets('a tile above the viewport that grows does not move the view', (
      tester,
    ) async {
      final grow = ValueNotifier<double>(100);
      addTearDown(grow.dispose);
      final controller = ScrollController(initialScrollOffset: 1000);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            layout: const MosaicLayout.masonry(),
            columns: const MosaicColumns.count(1),
            itemCount: 100,
            itemBuilder: (_, i) => i == 9
                ? ValueListenableBuilder<double>(
                    valueListenable: grow,
                    builder: (_, extent, __) => box(i, extent),
                  )
                : box(i, 100),
          ),
        ),
      );
      expect(rectOf(tester, 10).top, 0);

      grow.value = 200;
      await tester.pump();
      expect(rectOf(tester, 10).top, 0);
      expect(controller.offset, 1100);
    });
  });

  group('MosaicColumns', () {
    testWidgets('changing the column count keeps the first visible tile put', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Future<void> pumpWidth(double width) => tester.pumpWidget(
        harness(
          width: width,
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            columns: const MosaicColumns.minExtent(100),
            itemCount: 500,
            itemBuilder: (_, i) => box(i, varied(i)),
          ),
        ),
      );
      await pumpWidth(300);
      controller.jumpTo(2000);
      await tester.pump();
      final anchor = [
        for (var i = 0; i < 500; i++)
          if (isBuilt(i) && rectOf(tester, i).bottom > 0) i,
      ].first;
      final top = rectOf(tester, anchor).top;

      await pumpWidth(200); // three columns become two
      expect(rectOf(tester, anchor).top, closeTo(top, 1e-6));
    });
  });

  group('MosaicController', () {
    testWidgets('jumpToIndex lands on items never built before', (
      tester,
    ) async {
      final mosaic = MosaicController();
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            controller: mosaic,
            layout: const MosaicLayout.masonry(),
            columns: const MosaicColumns.count(3),
            rowGap: 8,
            itemCount: 3000,
            itemBuilder: (_, i) => box(i, varied(i)),
          ),
        ),
      );
      final done = mosaic.jumpToIndex(1500);
      await tester.pumpAndSettle();
      await done;
      expect(rectOf(tester, 1500).top, closeTo(0, 0.5));

      final back = mosaic.jumpToIndex(40);
      await tester.pumpAndSettle();
      await back;
      expect(rectOf(tester, 40).top, closeTo(0, 0.5));
    });

    testWidgets('animateToIndex centres the item', (tester) async {
      final mosaic = MosaicController();
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            controller: mosaic,
            itemCount: 400,
            itemBuilder: (_, i) => box(i, varied(i)),
          ),
        ),
      );
      final done = mosaic.animateToIndex(
        250,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await done;
      expect(rectOf(tester, 250).center.dy, closeTo(300, 0.5));
    });

    testWidgets('accounts for slivers before the grid', (tester) async {
      final mosaic = MosaicController();
      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 700)),
              SliverMosaicGrid.builder(
                controller: mosaic,
                itemCount: 200,
                itemBuilder: (_, i) => box(i, varied(i)),
              ),
            ],
          ),
        ),
      );
      final done = mosaic.jumpToIndex(120);
      await tester.pumpAndSettle();
      await done;
      expect(rectOf(tester, 120).top, closeTo(0, 0.5));
    });

    testWidgets('does nothing when detached', (tester) async {
      final mosaic = MosaicController();
      expect(mosaic.isAttached, isFalse);
      await mosaic.jumpToIndex(3);
    });
  });

  group('MosaicGrid', () {
    testWidgets('header and footer scroll with the tiles', (tester) async {
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            header: const SizedBox(key: ValueKey('header'), height: 50),
            footer: const SizedBox(key: ValueKey('footer'), height: 30),
            itemCount: 4,
            itemBuilder: (_, i) => box(i, 100),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const ValueKey('header'))).top, 0);
      expect(rectOf(tester, 0).top, 50);
      expect(rectOf(tester, 2).top, 150);
      expect(tester.getRect(find.byKey(const ValueKey('footer'))).top, 250);
    });

    testWidgets('onEndReached fires once per item count', (tester) async {
      var calls = 0;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Future<void> pumpCount(int count) => tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            scrollController: controller,
            endReachedThreshold: 100,
            onEndReached: () => calls += 1,
            itemCount: count,
            itemBuilder: (_, i) => box(i, 100),
          ),
        ),
      );
      await pumpCount(0);
      await tester.pump();
      expect(calls, 0, reason: 'never for an empty grid');

      await pumpCount(20); // 10 rows, 1000 px in a 600 px viewport
      await tester.pump();
      expect(calls, 0);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(calls, 1);
      controller.jumpTo(controller.position.maxScrollExtent - 10);
      await tester.pump();
      expect(calls, 1);

      await pumpCount(30);
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('fires right away when the first page does not fill the view', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        harness(
          MosaicGrid.builder(
            padding: EdgeInsets.zero,
            onEndReached: () => calls += 1,
            itemCount: 2,
            itemBuilder: (_, i) => box(i, 100),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('children constructor', (tester) async {
      await tester.pumpWidget(
        harness(
          MosaicGrid(
            padding: EdgeInsets.zero,
            children: [for (var i = 0; i < 3; i++) box(i, 10.0 * (i + 1))],
          ),
        ),
      );
      expect(rectOf(tester, 0), const Rect.fromLTWH(0, 0, 150, 20));
      expect(rectOf(tester, 2), const Rect.fromLTWH(0, 20, 150, 30));
    });
  });
}

class _CountLayouts extends SingleChildRenderObjectWidget {
  const _CountLayouts({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  _RenderCountLayouts createRenderObject(BuildContext context) =>
      _RenderCountLayouts(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCountLayouts renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderCountLayouts extends RenderProxyBox {
  _RenderCountLayouts(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}

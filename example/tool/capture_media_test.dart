// Renders the screenshots and GIF frames used by the README.
//
// Run from the example directory:
//
//   flutter test tool/capture_media_test.dart
//
// then assemble them with `python ../tool/build_media.py`. Frames land in
// ../screenshots/frames/<scene>/, one PNG per frame, at 2x.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:mosaic_grid_example/main.dart';
import 'package:mosaic_grid_example/src/board_page.dart';
import 'package:mosaic_grid_example/src/catalog_page.dart';
import 'package:mosaic_grid_example/src/sample_data.dart';

const _pixelRatio = 2.0;
final _framesRoot = Directory('../screenshots/frames');

void main() {
  setUpAll(_loadFonts);

  testWidgets('catalog on a phone: paging and go-to-item', (tester) async {
    final recorder = await _Recorder.start(
      tester,
      'catalog',
      const Size(390, 780),
    );
    await recorder.pumpApp(const MosaicGridGallery());
    await recorder.hold(const Duration(milliseconds: 1100), fps: 12);

    final position = _scrollPosition(find.byType(CatalogPage));
    await recorder.animate(
      position,
      to: position.maxScrollExtent,
      duration: const Duration(milliseconds: 2600),
    );
    // The footer is on screen: the next page loads.
    await recorder.hold(const Duration(milliseconds: 1300));
    await recorder.animate(
      position,
      to: position.pixels + 900,
      duration: const Duration(milliseconds: 1200),
    );

    final state = tester.state<CatalogPageState>(find.byType(CatalogPage));
    unawaited(state.goTo(13));
    await recorder.hold(const Duration(milliseconds: 1700));
    await recorder.hold(const Duration(milliseconds: 900), fps: 10);
    await recorder.finish();
  });

  testWidgets('catalog in a window being resized', (tester) async {
    final recorder = await _Recorder.start(
      tester,
      'adaptive',
      const Size(1240, 780),
    );
    final width = ValueNotifier<double>(400);
    addTearDown(width.dispose);
    await recorder.pumpApp(_ResizableWindow(width: width));
    await recorder.pumpFor(const Duration(milliseconds: 1100));
    _scrollPosition(find.byType(CatalogPage)).jumpTo(420);
    await recorder.hold(const Duration(milliseconds: 700), fps: 10);

    Future<void> resize(double from, double to, Duration duration) async {
      const fps = 15;
      final frames = duration.inMilliseconds * fps ~/ 1000;
      for (var f = 1; f <= frames; f++) {
        final t = Curves.easeInOut.transform(f / frames);
        width.value = from + (to - from) * t;
        await tester.pump(const Duration(milliseconds: 1000 ~/ fps));
        await recorder.shot(ms: 1000 ~/ fps);
      }
    }

    await resize(400, 1200, const Duration(milliseconds: 2800));
    await recorder.hold(const Duration(milliseconds: 1000), fps: 10);
    await resize(1200, 620, const Duration(milliseconds: 1800));
    await recorder.hold(const Duration(milliseconds: 900), fps: 10);
    await recorder.finish();
  });

  testWidgets('masonry board on a phone', (tester) async {
    final recorder = await _Recorder.start(
      tester,
      'board',
      const Size(390, 780),
    );
    await recorder.pumpApp(
      const MosaicGridGallery(home: GalleryShell(initialIndex: 1)),
    );
    await recorder.hold(const Duration(milliseconds: 700), fps: 10);
    await recorder.animate(
      _scrollPosition(find.byType(BoardPage)),
      to: 2600,
      duration: const Duration(milliseconds: 4200),
      curve: Curves.easeInOutSine,
    );
    await recorder.hold(const Duration(milliseconds: 800), fps: 10);
    await recorder.finish();
  });

  testWidgets('playground on a desktop', (tester) async {
    final recorder = await _Recorder.start(
      tester,
      'playground',
      const Size(1240, 780),
    );
    await recorder.pumpApp(
      const MosaicGridGallery(home: GalleryShell(initialIndex: 2)),
    );
    await recorder.hold(const Duration(milliseconds: 900), fps: 10);

    Future<void> tapThen(String label) async {
      await tester.tap(find.text(label));
      await recorder.hold(const Duration(milliseconds: 1100), fps: 10);
    }

    for (final label in [
      'Masonry',
      'Rows',
      'Start',
      'Center',
      'Stretch',
      '4',
      'Wide tiles',
      'Wide tiles',
      'Horizontal',
      'Horizontal',
    ]) {
      await tapThen(label);
    }
    await recorder.finish();
  });

  testWidgets('stills', (tester) async {
    Future<void> still(
      String name,
      Size size,
      Widget app, [
      double scrollTo = 0,
      Type page = CatalogPage,
    ]) async {
      final recorder = await _Recorder.start(tester, name, size);
      await recorder.pumpApp(app);
      await recorder.pumpFor(const Duration(milliseconds: 1100));
      if (scrollTo > 0) {
        _scrollPosition(find.byType(page)).jumpTo(scrollTo);
      }
      await recorder.pumpFor(const Duration(milliseconds: 400));
      await recorder.shot();
      await recorder.finish();
    }

    const desktop = Size(1280, 820);
    const phone = Size(390, 844);
    await still('still_catalog_desktop', desktop, const MosaicGridGallery());
    await still(
      'still_board_desktop',
      desktop,
      const MosaicGridGallery(home: GalleryShell(initialIndex: 1)),
    );
    await still(
      'still_playground_desktop',
      desktop,
      const MosaicGridGallery(home: GalleryShell(initialIndex: 2)),
    );
    await still('still_catalog_phone', phone, const MosaicGridGallery());
    await still(
      'still_board_phone',
      phone,
      const MosaicGridGallery(home: GalleryShell(initialIndex: 1)),
    );
    await still(
      'still_playground_phone',
      phone,
      const MosaicGridGallery(home: GalleryShell(initialIndex: 2)),
    );
  });

  testWidgets('GridView next to MosaicGrid', (tester) async {
    // The fixed-ratio grid is meant to overflow: keep its errors out of the
    // test result — the stripes are the point of the picture.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.toString().contains('overflowed')) {
        previous?.call(details);
      }
    };

    final recorder = await _Recorder.start(
      tester,
      'still_comparison',
      const Size(860, 700),
    );
    await recorder.pumpApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: galleryTheme(Brightness.light),
        home: const _Comparison(),
      ),
    );
    await recorder.pumpFor(const Duration(milliseconds: 300));
    await recorder.shot();
    await recorder.finish();
    FlutterError.onError = previous;
  });
}

ScrollPosition _scrollPosition(Finder within) {
  return find
      .descendant(of: within, matching: find.byType(Scrollable))
      .evaluate()
      .map((element) => (element as StatefulElement).state as ScrollableState)
      .firstWhere((state) => state.position.axis == Axis.vertical)
      .position;
}

class _Recorder {
  _Recorder._(this.tester, this.directory);

  static Future<_Recorder> start(
    WidgetTester tester,
    String name,
    Size size,
  ) async {
    tester.view
      ..physicalSize = size * _pixelRatio
      ..devicePixelRatio = _pixelRatio;
    // flutter_test draws shadows as thin black outlines; draw them for real.
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    final directory = Directory('${_framesRoot.path}/$name');
    await tester.runAsync(() async {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      directory.createSync(recursive: true);
    });
    return _Recorder._(tester, directory);
  }

  final WidgetTester tester;
  final Directory directory;
  final GlobalKey _boundary = GlobalKey();
  final List<int> _durations = <int>[];
  int _frame = 0;

  Future<void> pumpApp(Widget app) async {
    await tester.pumpWidget(RepaintBoundary(key: _boundary, child: app));
  }

  Future<void> pumpFor(Duration duration) async {
    const step = Duration(milliseconds: 50);
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
      await tester.pump(step);
    }
  }

  Future<void> hold(Duration duration, {int fps = 15}) async {
    final frames = duration.inMilliseconds * fps ~/ 1000;
    for (var f = 0; f < frames; f++) {
      await tester.pump(Duration(milliseconds: 1000 ~/ fps));
      await shot(ms: 1000 ~/ fps);
    }
  }

  Future<void> animate(
    ScrollPosition position, {
    required double to,
    required Duration duration,
    Curve curve = Curves.easeInOutCubic,
    int fps = 15,
  }) async {
    final from = position.pixels;
    final frames = duration.inMilliseconds * fps ~/ 1000;
    for (var f = 1; f <= frames; f++) {
      final target = from + (to - from) * curve.transform(f / frames);
      position.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      await tester.pump(Duration(milliseconds: 1000 ~/ fps));
      await shot(ms: 1000 ~/ fps);
    }
  }

  /// Captures one frame, shown for [ms] milliseconds in the GIF.
  Future<void> shot({int ms = 100}) async {
    _durations.add(ms);
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final name =
        '${directory.path}/${(_frame++).toString().padLeft(4, '0')}.png';
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(name).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> finish() async {
    await tester.runAsync(() async {
      File(
        '${directory.path}/durations.txt',
      ).writeAsStringSync(_durations.join(' '));
    });
    // Let pending timers (page loads, highlights) run out before the test ends.
    await pumpFor(const Duration(seconds: 4));
    debugDisableShadows = true;
  }
}

class _ResizableWindow extends StatelessWidget {
  const _ResizableWindow({required this.width});

  final ValueNotifier<double> width;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9EAF4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) => Container(
              width: value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: const MosaicGridGallery(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison();

  static final _products = List.generate(12, Product.sample);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget panel(String title, String subtitle, Color accent, Widget grid) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: grid,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          panel(
            'GridView',
            'childAspectRatio: 0.72 — every card the same height',
            const Color(0xFFB3261E),
            GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _products.length,
              itemBuilder: (_, i) => ProductCard(product: _products[i]),
            ),
          ),
          panel(
            'MosaicGrid',
            'MosaicLayout.rows() — each row fits its tallest card',
            const Color(0xFF2E9E62),
            MosaicGrid.builder(
              padding: const EdgeInsets.all(10),
              columnGap: 10,
              rowGap: 10,
              itemCount: _products.length,
              itemBuilder: (_, i) => ProductCard(product: _products[i]),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _loadFonts() async {
  final fonts = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final weight in ['light', 'regular', 'medium', 'bold', 'black']) {
    roboto.addFont(bytes('$fonts/roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(bytes('$fonts/materialicons-regular.otf'))).load();

  const consolas = 'C:/Windows/Fonts/consola.ttf';
  final mono = File(consolas).existsSync()
      ? consolas
      : '$fonts/robotocondensed-regular.ttf';
  await (FontLoader('monospace')..addFont(bytes(mono))).load();
}

String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && Directory(fromEnv).existsSync()) {
    return fromEnv;
  }
  // .../bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

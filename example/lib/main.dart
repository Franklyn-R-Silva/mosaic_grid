import 'package:flutter/material.dart';

import 'src/board_page.dart';
import 'src/catalog_page.dart';
import 'src/playground_page.dart';

void main() => runApp(const MosaicGridGallery());

/// The mosaic_grid gallery: a catalog in aligned rows, a masonry board and a
/// playground with every option.
class MosaicGridGallery extends StatelessWidget {
  /// Creates the gallery app.
  const MosaicGridGallery({super.key, this.home});

  /// Overrides the home screen; used by the screenshot script.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mosaic_grid gallery',
      debugShowCheckedModeBanner: false,
      theme: galleryTheme(Brightness.light),
      darkTheme: galleryTheme(Brightness.dark),
      home: home ?? const GalleryShell(),
    );
  }
}

/// The gallery's theme for [brightness].
ThemeData galleryTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5),
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// The three demos behind a navigation bar on phones and a rail on wider
/// screens.
class GalleryShell extends StatefulWidget {
  /// Creates the shell.
  const GalleryShell({super.key, this.initialIndex = 0});

  /// The demo shown first.
  final int initialIndex;

  @override
  State<GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<GalleryShell> {
  late int _index = widget.initialIndex;

  static const _destinations = [
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Catalog'),
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Board'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Playground'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _index,
      children: const [CatalogPage(), BoardPage(), PlaygroundPage()],
    );
    void select(int index) => setState(() => _index = index);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Scaffold(
            body: pages,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: select,
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: label,
                  ),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: _Logo(),
                ),
                destinations: [
                  for (final (icon, selected, label) in _destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages),
            ],
          ),
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome_mosaic_rounded, color: scheme.onPrimary),
    );
  }
}

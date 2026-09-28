import 'package:flutter/material.dart';
import 'package:mosaic_grid/mosaic_grid.dart';

import 'sample_data.dart';

enum _Arrangement { rows, masonry }

/// Every option of the grid on one screen, with the code that produces it.
class PlaygroundPage extends StatefulWidget {
  /// Creates the playground.
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  _Arrangement _arrangement = _Arrangement.rows;
  MosaicRowFit _fit = MosaicRowFit.stretch;
  int? _columns = 3; // null: adaptive
  double _gap = 8;
  bool _spans = true;
  Axis _axis = Axis.vertical;

  static const _itemCount = 120;

  MosaicLayout get _layout => switch (_arrangement) {
    _Arrangement.rows => MosaicLayout.rows(fit: _fit),
    _Arrangement.masonry => const MosaicLayout.masonry(),
  };

  MosaicColumns get _mosaicColumns => switch (_columns) {
    final count? => MosaicColumns.count(count),
    null => const MosaicColumns.minExtent(140),
  };

  double _extentOf(int i) => 56.0 + (i * 53) % 110;

  String get _code {
    final layout = switch (_arrangement) {
      _Arrangement.rows => 'MosaicLayout.rows(fit: MosaicRowFit.${_fit.name})',
      _Arrangement.masonry => 'MosaicLayout.masonry()',
    };
    final columns = switch (_columns) {
      final count? => 'MosaicColumns.count($count)',
      null => 'MosaicColumns.minExtent(140)',
    };
    return [
      'MosaicGrid.builder(',
      if (_axis == Axis.horizontal) '  scrollDirection: Axis.horizontal,',
      '  layout: const $layout,',
      '  columns: const $columns,',
      '  columnGap: ${_gap.round()},',
      '  rowGap: ${_gap.round()},',
      if (_spans) '  columnSpan: (i) => i % 7 == 0 ? 2 : 1,',
      '  itemCount: $_itemCount,',
      '  itemBuilder: (context, i) => Tile(i),',
      ')',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final grid = MosaicGrid.builder(
      key: ValueKey(_axis),
      padding: const EdgeInsets.all(16),
      scrollDirection: _axis,
      layout: _layout,
      columns: _mosaicColumns,
      columnGap: _gap,
      rowGap: _gap,
      columnSpan: _spans ? (i) => i % 7 == 0 ? 2 : 1 : null,
      itemCount: _itemCount,
      itemBuilder: (context, i) => _DemoTile(
        index: i,
        extent: _extentOf(i),
        axis: _axis,
        wide: _spans && i % 7 == 0,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Playground')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [..._controls(), _CodePreview(_code)],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: grid),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: 132,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final control in _controls())
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: control,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: grid),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _controls() => [
    _Section(
      label: 'Layout',
      child: SegmentedButton<_Arrangement>(
        segments: const [
          ButtonSegment(
            value: _Arrangement.rows,
            label: Text('Rows'),
            icon: Icon(Icons.table_rows_rounded),
          ),
          ButtonSegment(
            value: _Arrangement.masonry,
            label: Text('Masonry'),
            icon: Icon(Icons.dashboard_rounded),
          ),
        ],
        selected: {_arrangement},
        onSelectionChanged: (value) =>
            setState(() => _arrangement = value.single),
      ),
    ),
    _Section(
      label: 'Row fit',
      child: SegmentedButton<MosaicRowFit>(
        showSelectedIcon: false,
        segments: [
          for (final fit in MosaicRowFit.values)
            ButtonSegment(value: fit, label: Text(_title(fit.name))),
        ],
        selected: {_fit},
        onSelectionChanged: _arrangement == _Arrangement.rows
            ? (value) => setState(() => _fit = value.single)
            : null,
      ),
    ),
    _Section(
      label: 'Columns',
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 2, label: Text('2')),
          ButtonSegment(value: 3, label: Text('3')),
          ButtonSegment(value: 4, label: Text('4')),
          ButtonSegment(value: 0, label: Text('Auto')),
        ],
        selected: {_columns ?? 0},
        onSelectionChanged: (value) =>
            setState(() => _columns = value.single == 0 ? null : value.single),
      ),
    ),
    _Section(
      label: 'Gap · ${_gap.round()} px',
      child: SizedBox(
        width: 260,
        child: Slider(
          value: _gap,
          max: 24,
          divisions: 12,
          onChanged: (value) => setState(() => _gap = value),
        ),
      ),
    ),
    _Section(
      label: 'Options',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChip(
            label: const Text('Wide tiles'),
            selected: _spans,
            onSelected: (value) => setState(() => _spans = value),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Horizontal'),
            selected: _axis == Axis.horizontal,
            onSelected: (value) =>
                setState(() => _axis = value ? Axis.horizontal : Axis.vertical),
          ),
        ],
      ),
    ),
  ];

  static String _title(String name) =>
      name[0].toUpperCase() + name.substring(1);
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CodePreview extends StatelessWidget {
  const _CodePreview(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.5,
              color: scheme.onInverseSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.index,
    required this.extent,
    required this.axis,
    required this.wide,
  });

  final int index;
  final double extent;
  final Axis axis;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    return SizedBox(
      width: vertical ? null : extent,
      height: vertical ? extent : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: illustrationGradient((index * 29.0) % 360),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                wide ? 'span 2' : '${extent.round()} px',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

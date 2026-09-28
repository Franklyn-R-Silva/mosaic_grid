import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mosaic_grid/mosaic_grid.dart';

import 'sample_data.dart';

/// A paged product catalog: aligned rows whose cards all grow to the tallest
/// card of the row, featured products two columns wide, and "go to item".
class CatalogPage extends StatefulWidget {
  /// Creates the catalog demo.
  const CatalogPage({
    super.key,
    this.scrollController,
    this.pageDelay = const Duration(milliseconds: 900),
  });

  /// Optional scroll controller, used by the screenshot script.
  final ScrollController? scrollController;

  /// How long a simulated page load takes.
  final Duration pageDelay;

  @override
  State<CatalogPage> createState() => CatalogPageState();
}

/// State of [CatalogPage]; public so the screenshot script can drive it.
class CatalogPageState extends State<CatalogPage> {
  static const _pageSize = 24;
  static const _total = 240;

  final _products = <Product>[];
  final _mosaic = MosaicController();
  bool _loading = false;
  int? _highlighted;
  Timer? _highlightTimer;

  bool get _hasMore => _products.length < _total;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) {
      return;
    }
    setState(() => _loading = true);
    await Future<void>.delayed(widget.pageDelay);
    if (!mounted) {
      return;
    }
    final start = _products.length;
    setState(() {
      _products.addAll(
        List.generate(_pageSize, (i) => Product.sample(start + i)),
      );
      _loading = false;
    });
  }

  /// Scrolls to the product at [index] and highlights it for a moment.
  Future<void> goTo(int index) async {
    _highlightTimer?.cancel();
    setState(() => _highlighted = index);
    await _mosaic.animateToIndex(
      index,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      alignment: 0.2,
    );
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _highlighted = null);
      }
    });
  }

  Future<void> _promptGoTo() async {
    final index = await showDialog<int>(
      context: context,
      builder: (context) => _GoToDialog(count: _products.length),
    );
    if (index != null) {
      await goTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catalog'),
            Text(
              '${_products.length} of $_total products',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _products.isEmpty ? null : _promptGoTo,
        icon: const Icon(Icons.near_me_rounded),
        label: const Text('Go to item'),
      ),
      body: MosaicGrid.builder(
        scrollController: widget.scrollController,
        controller: _mosaic,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        columns: const MosaicColumns.minExtent(170, maxCount: 4),
        columnGap: 12,
        rowGap: 12,
        itemCount: _products.length,
        columnSpan: (i) => _products[i].featured ? 2 : 1,
        header: const _CatalogBanner(),
        footer: _CatalogFooter(
          loading: _loading || _hasMore,
          count: _products.length,
        ),
        onEndReached: _loadMore,
        itemBuilder: (context, i) =>
            ProductCard(product: _products[i], highlighted: _highlighted == i),
      ),
    );
  }
}

/// A product card whose height follows its content.
class ProductCard extends StatelessWidget {
  /// Creates a card for [product].
  const ProductCard({
    super.key,
    required this.product,
    this.highlighted = false,
  });

  /// The product shown.
  final Product product;

  /// Whether to draw attention to the card.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      // spaceBetween, not Spacer: the grid measures each card with an
      // unbounded height first, then stretches it to the row. spaceBetween
      // is a no-op in the first pass and pins the price to the bottom in the
      // second.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Illustration(product: product),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in product.tags) _TagChip(tag),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _StockDot(stock: product.stock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final soldOut = product.stock == 0;
    return AspectRatio(
      aspectRatio: product.featured ? 2.4 : 1.45,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: illustrationGradient(product.hue)),
        child: Stack(
          children: [
            Center(
              child: Icon(
                product.icon,
                size: product.featured ? 64 : 44,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _Pill(
                label: product.featured ? 'Featured' : product.code,
                background: Colors.black.withValues(alpha: 0.28),
                foreground: Colors.white,
              ),
            ),
            if (soldOut)
              const Positioned(
                right: 8,
                top: 8,
                child: _Pill(
                  label: 'Sold out',
                  background: Color(0xFFFFFFFF),
                  foreground: Color(0xFFB3261E),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StockDot extends StatelessWidget {
  const _StockDot({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = switch (stock) {
      0 => (theme.colorScheme.error, 'Out'),
      < 20 => (const Color(0xFFE8A317), '$stock left'),
      _ => (const Color(0xFF2E9E62), 'In stock'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CatalogBanner extends StatelessWidget {
  const _CatalogBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spring collection',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Every row is as tall as its tallest card. '
                'Featured products span two columns.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogFooter extends StatelessWidget {
  const _CatalogFooter({required this.loading, required this.count});

  final bool loading;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading more products…',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            : Text(
                "That's all $count products.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _GoToDialog extends StatefulWidget {
  const _GoToDialog({required this.count});

  final int count;

  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog> {
  final _field = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final number = int.tryParse(_field.text);
    if (number == null || number < 1 || number > widget.count) {
      setState(() => _error = 'Enter a number from 1 to ${widget.count}');
      return;
    }
    Navigator.of(context).pop(number - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to item'),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Item number',
          helperText: 'Loaded so far: ${widget.count}',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}

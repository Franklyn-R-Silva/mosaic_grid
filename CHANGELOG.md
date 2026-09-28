# Changelog

<!-- Add upcoming changes under a new "## Unreleased" heading. -->

## 0.1.0

First release.

### Layouts

- `MosaicLayout.rows` — tiles fill rows from the start edge, and every row is
  as tall as its tallest tile. `MosaicRowFit` decides what shorter tiles do:
  `stretch` (the default), `start`, `center` or `end`.
- `MosaicLayout.masonry` — every tile keeps its height and drops into the
  column that ends first.
- `columnSpan` — tiles spanning several columns, in both layouts, built lazily.

### Columns

- `MosaicColumns.count`, `MosaicColumns.minExtent` (with an optional
  `maxCount`) and `MosaicColumns.maxExtent`, resolved from the grid's own
  cross-axis extent on every layout.

### Widgets

- `MosaicGrid` — a scroll view with `header`, `footer`, `onEndReached` (at most
  once per `itemCount`) and every usual scroll view option.
- `SliverMosaicGrid` — the same grid as a sliver, for `CustomScrollView`.
- `MosaicController` — `jumpToIndex` and `animateToIndex`, with `alignment`,
  exact even for items never built.

### Behaviour

- Positions come from a ledger recorded in index order from the first item,
  so scrolling back up never drifts.
- Tiles already laid out are not laid out again while scrolling; stretched rows
  need no `IntrinsicHeight`.
- A tile above the viewport that changes size does not move the visible
  content, and neither does a change of column count.
- Measuring is time-sliced: a long jump (a scrollbar drag, a far `jumpTo`)
  fills in over a few frames instead of blocking one.
- Masonry lookups and re-flows stay logarithmic in the number of items, even
  when one column runs far longer than the others.
- Vertical and horizontal scrolling, right-to-left, keep-alives, semantics
  indexes and keyed reordering.

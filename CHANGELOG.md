# Changelog

<!-- Add upcoming changes under a new "## Unreleased" heading. -->

## 0.1.3

### Fixes

- A tile shorter than its row — stretched to the row's height, the default
  fit — that then grows no longer overflows. When a section inside it opened,
  an image loaded or its text changed, the row kept its old height and the
  tile was squeezed into it ("A RenderFlex overflowed by … pixels"). The row
  now grows, as it already did when the tallest tile of the row grew.
- In the rows layout, a tile whose `columnSpan` shrinks moves back into the
  row before it when it fits there now. It stayed at the start of the next
  row and left a gap: a card made wide and then narrow again never returned
  to its place.

### Docs

- `MosaicController.jumpToIndex` and `animateToIndex` state that an index
  outside the grid completes them with a `RangeError`.

## 0.1.2

### Fixes

- Changing the column count, the row gap or the layout no longer freezes the
  app when the grid is scrolled far down. Every item above the view was built
  and measured again in that one frame — close to a second for 20,000 plain
  tiles, more with real cards — when a phone rotated or a window was resized
  across a column breakpoint. The grid now places those items from the sizes
  it already recorded. With new column widths, each tile above is measured
  again as it scrolls back into view, and the view stays still while that
  happens.
- A grid that replaces another one with the same `MosaicController` — a new
  `key`, an `AnimatedSwitcher` — no longer fails in debug builds with
  "A MosaicController can only drive one grid at a time", which turned the
  whole grid into an error widget. The new grid mounts before the old one is
  disposed; the controller now drives the newer one.
- A drag during `animateToIndex` stops it. The grid used to pull the view
  back to the item as soon as the user let go.

### Docs

- `MosaicController` has a documented constructor.

## 0.1.1

### Fixes

- `onEndReached` fires again when a new page arrives and still does not fill
  the viewport. Only the first page was checked: with nothing to scroll, no
  scroll metric changed, no notification came, and the page after it was
  never asked for.
- `onEndReached` no longer stays silent after the list is replaced by another
  one of the same length, such as the first page of a new search. It fired at
  most once per `itemCount` and never re-armed; now scrolling away from the end
  and back re-arms it.

### Added

- `MosaicGrid.endReachedKey` — what the items were loaded for (a search term, a
  filter). When it changes, the grid forgets that `onEndReached` already fired
  and checks the end again: the fix for a list replaced in place while the view
  stays at the end, which no scroll or change of `itemCount` reveals.

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

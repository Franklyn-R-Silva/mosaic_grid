# mosaic_grid example

A small gallery of the [mosaic_grid](https://pub.dev/packages/mosaic_grid)
package:

- **Catalog** — a paged product catalog in aligned rows: every row is as tall
  as its tallest card, featured products span two columns, the next page loads
  at the end, and "Go to item" jumps to any product.
- **Board** — a masonry board of notes of every height.
- **Playground** — every option of the grid, with the code that produces it.

```bash
flutter run -d chrome
```

Or open the [live demo](https://franklyn-r-silva.github.io/mosaic_grid/): this
app, built from `main` on every merge. Only the web runner is checked in; for
another platform, run `flutter create --platforms=<platform> .` here first.

The README images are rendered from this app:

```bash
flutter test tool/capture_media_test.dart   # renders the frames
python ../tool/build_media.py               # builds the GIFs and PNGs
```

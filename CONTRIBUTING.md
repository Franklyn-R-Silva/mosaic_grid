# Contributing to mosaic_grid

Thanks for stopping by. mosaic_grid has one maintainer, so every bug report,
question and pull request helps, and none of them has to be perfect: a
two-line issue with a screenshot is enough to start.

- **Something broke, or you want a feature?**
  [Open an issue](https://github.com/Franklyn-R-Silva/mosaic_grid/issues/new/choose).
  Only "what happened" is required.
- **A question, or not sure it is a bug?** Ask in
  [Discussions](https://github.com/Franklyn-R-Silva/mosaic_grid/discussions/categories/q-a).
- **Want to write code or docs?** Pick an issue labelled
  [`good first issue`](https://github.com/Franklyn-R-Silva/mosaic_grid/labels/good%20first%20issue)
  or [`help wanted`](https://github.com/Franklyn-R-Silva/mosaic_grid/labels/help%20wanted),
  and leave a comment saying you are on it so nobody duplicates the work. An
  idea of your own is welcome too; for a large change, open an issue first so
  we can agree on the shape before you spend the time.

Issues and pull requests usually get a first reply within a few days. Please be
kind ([Code of Conduct](CODE_OF_CONDUCT.md)), and report security problems
[privately](SECURITY.md), not in an issue.

## Your first contribution in 5 minutes

You need Git and **Flutter 3.32 or newer** (`flutter --version`). That is the
oldest Flutter the package supports, and CI tests on it.

```sh
# Fork the repository on GitHub, then:
git clone https://github.com/<your-user>/mosaic_grid.git
cd mosaic_grid
flutter pub get

# The whole suite: widget tests, no device or emulator needed
flutter test

# The gallery app (catalog, masonry board, playground) in Chrome
cd example
flutter run -d chrome
cd ..

git checkout -b fix/short-description
```

Only the web runner of the example is checked in. To run it on a phone or as
a desktop app, generate the runner first, once:
`flutter create --platforms=android .` (or `ios`, `linux`, `macos`,
`windows`) inside `example/`. The generated folders are gitignored.

Make the change, add a test next to similar ones (see [Tests](#tests)), push
the branch and open a pull request. That's it: CI runs every other check.

You can also see the example without installing anything: the
[live demo](https://franklyn-r-silva.github.io/mosaic_grid/) is the same app,
rebuilt from `main` on every merge.

### Before you push

These three catch nearly everything CI does (the full list is in
[What CI checks](#what-ci-checks)):

```sh
dart format .                  # auto-format
flutter analyze --fatal-infos  # static analysis; infos fail the build
flutter test                   # the whole suite
```

Note `--fatal-infos`: a lint *info* fails CI, not just a warning.

### After you open the pull request

- **First PR here?** GitHub holds the CI run until the maintainer approves it.
  That is GitHub's default for forks, not a judgement on your change.
- **CI goes red and you don't know why?** Say so in the PR. Help is part of the
  review.
- **No version bump needed.** A line under `## Unreleased` in `CHANGELOG.md`
  is welcome; if you skip it, it is written when the release is cut, and you
  are credited there.
- **`main` moved under you?** The branch has to be up to date before merging;
  the *Update branch* button on the PR does it, and either of us can press it.
- With *Allow edits by maintainers* checked, small fixups (a doc line, a test
  name) can be pushed onto your branch instead of going back and forth.
- Draft PRs are welcome when you want feedback early.

## Changing the code

The README's [How it works](README.md#how-it-works) is the two-minute version
of the design: a *ledger* records, in index order from item 0, the columns
each item occupies and where its slot starts and ends.

### Where things live

```
lib/
  mosaic_grid.dart                # Public library: what is exported
  src/
    mosaic_columns.dart           # MosaicColumns: count, minExtent, maxExtent
    mosaic_layout.dart            # MosaicLayout (rows, masonry), MosaicRowFit
    widgets/
      mosaic_grid.dart            # MosaicGrid: scroll view, header/footer, onEndReached
      sliver_mosaic_grid.dart     # SliverMosaicGrid and MosaicController
    rendering/
      render_sliver_mosaic.dart   # The sliver render object: lazy layout, locating an item
      mosaic_ledger.dart          # Placement record for rows and masonry
      mosaic_cell.dart            # Per-tile render object: measure, then stretch
test/                             # See "Tests" below
example/
  lib/                            # The gallery app, also the live demo
  tool/capture_media_test.dart    # Renders the README frames (run by hand)
tool/
  build_media.py                  # Turns those frames into the README GIFs and PNGs
```

### Tests

- `test/mosaic_ledger_test.dart` — `MosaicColumns` and the ledgers: placement,
  truncation, windows. Plain unit tests, the fastest place for layout math.
- `test/mosaic_ledger_property_test.dart` — the ledgers against a brute-force
  model, on random grids.
- `test/mosaic_grid_test.dart` — widget tests: rows, masonry, columns,
  `MosaicController`, paging. The `harness()`, `box()` and `rectOf()` helpers
  at the top lay a grid out at a fixed size and read back where each tile
  landed.

### Guidelines

- Keep the package **dependency-free** at runtime (Flutter SDK only).
- All **public** members have `///` documentation comments, in English; pana
  checks the coverage.
- Add or update a **test** for any behavior change.
- Match the existing style; `analysis_options.yaml` is the source of truth.

### Updating the README media

Every image in the README is rendered from the example app, so it matches the
code. After a visual change:

```sh
cd example
flutter test tool/capture_media_test.dart   # renders the frames
cd ..
python tool/build_media.py                  # builds the GIFs and PNGs (needs Pillow)
```

### Commit messages

This project uses **Conventional Commits**: they keep the history readable and
make the next version bump obvious at a glance. Don't let it block you; a
title can be fixed before merge.

| Prefix | When to use | Version effect |
|---|---|---|
| `feat: ...` | New feature | minor bump |
| `fix: ...` | Bug fix | patch bump |
| `feat!: ...` | Breaking change | major bump |
| `perf: ...` | Faster layout or scrolling, same behavior | patch bump |
| `docs: ...` | Documentation only | no bump |
| `test: ...` | Adding/fixing tests | no bump |
| `refactor: ...` | Refactor without behavior change | no bump |
| `chore: ...` / `ci: ...` | Maintenance, CI, tooling | no bump |

### What CI checks

Every pull request runs these:

| Check | What it runs |
|---|---|
| `check` | format, `flutter analyze --fatal-infos` (package and example), `flutter pub publish --dry-run` |
| `test (stable)` | the suite on the current stable Flutter |
| `test (beta)` | the suite on the next Flutter |
| `min Flutter (3.32.0)` | analyze and the suite on the oldest Flutter `pubspec.yaml` claims |
| `build demo` | `flutter build web` of the example, the app behind the live demo |
| `pana` | pub.dev's scorer; fails on any pub point below the maximum (160/160) |
| `dependency review` | fails if the PR adds a package or action with a known vulnerability |
| `CodeQL` | GitHub's code scanning of the workflows and the media script |

Actions in `.github/workflows/` are pinned to a full commit SHA with the version
as a trailing comment (`uses: owner/action@<sha> # vX.Y.Z`); Dependabot keeps
both up to date. A tag can be moved to point at other code; a SHA cannot.

## For maintainers

### Release process

1. Pick the version from the commits since the last tag — `feat:` means a minor
   bump, `fix:` a patch, `feat!:` a major.
2. In one commit, set `version:` in `pubspec.yaml` and turn `## Unreleased` in
   `CHANGELOG.md` into `## x.y.z`, crediting outside contributors.
3. Push the commit, then the tag:

   ```sh
   git tag v0.2.0
   git push origin main v0.2.0
   ```

   [`release.yaml`](.github/workflows/release.yaml) checks that the tag
   matches `pubspec.yaml`, runs analyze and the suite, and creates the GitHub
   Release from the CHANGELOG section plus the merged PRs, grouped by label
   ([`.github/release.yml`](.github/release.yml)).
4. Publish to pub.dev from a clean checkout of the tag: `flutter pub publish`.

### Dependency updates

Dependabot opens one grouped PR a month for the GitHub Actions and one for pub
(the package and `example/`). Updates wait seven days after a release, so a
hijacked one is usually pulled before it reaches a PR. They go through the same
checks as anything else.

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).

# Contributing to mosaic_grid

First off, thank you for taking the time to contribute! 🎉

This project is open to everyone. Whether you are fixing a typo, reporting a
bug, or adding a feature, your help is welcome.

## Ways to contribute

- **Report a bug** — open a [bug report issue](../../issues/new?template=bug_report.md).
- **Request a feature** — open a [feature request issue](../../issues/new?template=feature_request.md).
- **Improve the docs** — the README, dartdoc comments and the example app.
- **Send code** — fix a bug or implement a feature via a pull request.

## How pull requests work

Anyone can contribute code without being added to the repository. The standard
GitHub flow is:

1. **Fork** the repository (top-right "Fork" button).
2. **Clone** your fork and create a branch:
   ```bash
   git clone https://github.com/<your-username>/mosaic_grid.git
   cd mosaic_grid
   git checkout -b fix/short-description
   ```
3. **Make your change** and keep it focused — one topic per pull request.
4. **Run the checks** locally (see below) so CI passes.
5. **Commit** with a clear message and **push** to your fork.
6. **Open a pull request** against the `main` branch and fill in the template.

A maintainer will review it. CI must be green before a PR can be merged.

## Local setup

```bash
flutter pub get
```

## Before you push — run the same checks as CI

```bash
dart format .                                   # format the code
dart format --output=none --set-exit-if-changed .   # verify formatting
flutter analyze                                 # static analysis (must be clean)
flutter test                                    # all tests must pass
```

If you add or change public API, please also run:

```bash
flutter pub publish --dry-run                   # must report 0 warnings
```

## Coding guidelines

- Keep the package **dependency-free** at runtime (Flutter SDK only). Please do
  not add third-party runtime dependencies.
- All **public** members must have `///` documentation comments, in **English**.
- Prefer `const` constructors and small, composable widgets.
- Match the existing style; `analysis_options.yaml` is the source of truth.
- Add or update **tests** for any behavior change.
- Update the **`## Unreleased`** section of `CHANGELOG.md`.

## Reporting security issues

Please do not open public issues for security vulnerabilities. Instead, contact
the maintainer privately (see `CODE_OF_CONDUCT.md`).

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).

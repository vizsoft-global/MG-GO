# Test fonts

`NotoSansArabic-Variable.ttf` is the same face the app resolves at runtime through
`GoogleFonts.notoSansArabicTextTheme` (see `lib/core/theme/app_theme.dart`).

It is committed rather than fetched because Arabic **overflow** is font-specific:
`google_fonts` downloads at runtime and returns nothing under `flutter test`, so
without this file the Arabic layout tests would measure a fallback face and prove
nothing about what a rider actually sees.

- Source: <https://github.com/google/fonts/tree/main/ofl/notosansarabic>
- Licence: SIL Open Font License 1.1
- Used by: `test/arabic_overflow_test.dart`

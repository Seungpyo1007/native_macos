# native_macos example

One window with every widget in `native_macos`: Liquid Glass panels over a
colorful backdrop, buttons, toggles, a segmented control, a pop-up button, a
context menu, a slider, and progress indicators.

```sh
flutter run -d macos
```

Glass needs macOS 26 or later. On older macOS the panels use
`NSVisualEffectView`, and on other platforms every widget shows its Flutter
fallback.

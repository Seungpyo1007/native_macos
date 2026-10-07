## 0.1.0

* Initial release.
* `NativeGlassContainer` draws an `NSGlassEffectView` under its child on
  macOS 26 and later, and an `NSVisualEffectView` before.
* AppKit controls: `NativeButton` (push, glass, and borderless bezels, tint
  prominence, border shape, SF Symbols), `NativeSwitch`, `NativeCheckbox`,
  `NativeSegmentedControl`, `NativeSlider`, `NativePopUpButton`, and
  `NativeProgressIndicator`.
* `showNativeAlert` shows an `NSAlert` as a sheet or a modal window, with
  explicit Return and Escape buttons.
* `showNativeMenu` pops up an `NSMenu` at a pointer position.
* `NativeInputBlocker` stops native views from taking clicks under overlays.
* `NativeMacos` reports whether native views and Liquid Glass are available.
* Every widget shows a Flutter fallback on other platforms.

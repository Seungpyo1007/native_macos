## 0.2.0

* `NativeToolbar` puts a real `NSToolbar` on the window, declared in Dart:
  `NativeToolbarButton` (SF Symbols, prominent style, tint, and badges on
  macOS 26), `NativeToolbarSegments`, `NativeToolbarMenu`,
  `NativeToolbarSearch`, and `NativeToolbarSpace`. The toolbar follows the
  app's theme brightness and comes back when a route on top of it is popped.

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

## 0.2.1

* Fix `NativeMacos.hasLiquidGlass` being true for apps built with an Xcode
  older than 26, which draw no glass even on macOS 26. The native side now
  answers for the build; `NativeMacos.loadCapabilities()` fetches that answer
  ahead of the first native widget.
* Fix the toolbar of a hidden `IndexedStack` tab, or of a route covered by an
  opaque route, owning the window. The newest visible `NativeToolbar` owns it
  now, and a page without one removes it.
* Disable toolbar items while a dialog or another route covers the toolbar's
  route, or a `NativeInputBlocker` above it blocks input, so they cannot act
  behind the overlay.
* Fix toolbars in different windows mirroring each other's item changes,
  which could also crash with an out-of-range index. Each toolbar has its own
  identifier now.
* Keep the toolbar search field, with its text and focus, when items before
  it are added or removed. Items before the first change are no longer
  rebuilt.
* Restore the window's title, title visibility, and toolbar style when the
  last `NativeToolbar` goes away, not only its toolbar and appearance.
* Fix `NativeSlider` ignoring Dart's value after a keyboard or VoiceOver
  change, which never ended the drag. Every change without a mouse drag now
  ends it and reports `onChangeEnd`.
* Report a native view's size again when the system appearance changes or the
  view moves into a window, and only once per update.
* Report native failures and a missing plugin through `FlutterError` instead
  of unhandled asynchronous errors, for control updates and the toolbar.
* Fix views and the toolbar of a run before a hot restart answering for the
  new run: channel names carry a per-run session, and the toolbar of a
  previous run is removed.
* `showNativeAlert(asSheet: false)` no longer needs a window.

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

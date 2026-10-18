<p align="center">
  <img src="https://raw.githubusercontent.com/Seungpyo1007/native_macos/main/assets/native_macos-logo.png" alt="native_macos logo: a Mac window with three title bar dots, a switch that is on, and a capsule button" width="128">
</p>

<h1 align="center">native_macos</h1>

<p align="center">
  <a href="https://pub.dev/packages/native_macos"><img src="https://img.shields.io/pub/v/native_macos" alt="pub version"></a>
  <a href="https://pub.dev/packages/native_macos/score"><img src="https://img.shields.io/pub/points/native_macos" alt="pub points"></a>
  <a href="https://github.com/Seungpyo1007/native_macos/actions/workflows/ci.yml"><img src="https://github.com/Seungpyo1007/native_macos/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Seungpyo1007/native_macos/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

Real AppKit controls and Liquid Glass in Flutter macOS apps. Each widget
embeds a native view with `AppKitView`, so macOS draws it: the glass refracts
your Flutter content, and buttons, switches, and sliders look and behave like
every other Mac app, including after the next macOS update. Nothing here is a
Flutter imitation.

```dart
NativeGlassContainer(
  cornerRadius: 20,
  style: NativeGlassStyle.clear,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        NativeButton(
          label: 'Share',
          symbol: 'square.and.arrow.up',
          style: NativeButtonStyle.glass,
          onPressed: share,
        ),
        NativeSwitch(value: sync, onChanged: (v) => setState(() => sync = v)),
      ],
    ),
  ),
)
```

<p align="center">
  <img src="https://raw.githubusercontent.com/Seungpyo1007/native_macos/main/assets/native_macos-showcase.png" alt="The example app in light and dark mode on macOS 27: native push, primary, glass, and destructive buttons, a switch, a checkbox, a segmented control, a pop-up button, a slider, progress indicators, and a small glass panel" width="720">
</p>

## Platform support

| Platform | Native views | Notes |
| --- | --- | --- |
| macOS 26 and later | Yes | Liquid Glass, glass bezels, tint prominence, border shapes. |
| macOS 12 to 25 | Yes | Same controls without glass. Glass surfaces use `NSVisualEffectView`; glass buttons use the push bezel. |
| Other platforms and web | No | Each widget shows a Flutter fallback, or the `fallback` you pass. |

Glass needs Xcode 26 or later at build time. With an older Xcode the package
still builds and uses the pre-26 look. `NativeGlassContainer.interactive`
needs macOS 27 and Xcode 27.

## Features

- `NativeToolbar`: a real `NSToolbar` in the window's title bar, with
  buttons, segments, menus, and a search field declared in Dart.
- `NativeGlassContainer`: an `NSGlassEffectView` sized by its child and
  painted under it.
- `NativeButton`: `NSButton` with push, glass, or borderless bezels, tint
  prominence, border shape, control size, SF Symbols, and destructive style.
- `NativeSwitch`, `NativeCheckbox`, `NativeSegmentedControl`,
  `NativeSlider`, `NativePopUpButton`, `NativeProgressIndicator`.
- `showNativeAlert`: an `NSAlert` as a sheet or a modal window.
- `showNativeMenu`: an `NSMenu` at the pointer, for context menus.
- `NativeInputBlocker`: keeps native views from taking clicks under overlays.
- Native views follow your app's theme brightness and text direction, and
  use the user's accent color unless you pass a tint.

## Installation

```sh
flutter pub add native_macos
```

The package requires Dart 3.13 and Flutter 3.47 or newer. No entitlements
are needed; everything works in the App Sandbox.

## Usage

### Toolbar

Wrap a page in `NativeToolbar` to put a real `NSToolbar` on the window. The
toolbar is window chrome drawn by AppKit, not a widget in your layout, so it
looks and behaves like the toolbar in Finder or Mail.

```dart
NativeToolbar(
  title: 'Inbox',
  items: [
    NativeToolbarSegments(
      id: 'view',
      labels: const ['List', 'Grid'],
      symbols: const ['list.bullet', 'square.grid.2x2'],
      selectedIndex: view,
      onChanged: (i) => setState(() => view = i),
    ),
    const NativeToolbarSpace.flexible(),
    NativeToolbarButton(
      id: 'compose',
      label: 'Compose',
      symbol: 'square.and.pencil',
      badge: const NativeToolbarBadge.count(3),
      onPressed: compose,
    ),
    NativeToolbarSearch(id: 'search', onSubmitted: search),
  ],
  child: page,
)
```

Each item needs an `id` that is unique within the toolbar. A window has one
toolbar: the newest `NativeToolbar` owns it, and the one below takes over
when it is removed, as when a route is popped. While a toolbar is shown, the
window follows your app's theme brightness. The search field keeps its own
text and reports edits through `onChanged` and `onSubmitted`.

### Glass styles

`NativeGlassStyle.regular`, the default as in AppKit, is frosted: it keeps
text legible, and on a large panel it looks much like a blur.
`NativeGlassStyle.clear` is more transparent and visibly bends the content
behind its edges, which is the lens look most people know as Liquid Glass.
Use `clear` over colorful content, and `regular` where the panel holds a lot
of text.

### Controls

Controls are driven by your state, like Flutter's own. A null callback
disables the control.

```dart
NativeSegmentedControl(
  labels: const ['Icons', 'List', 'Columns'],
  selectedIndex: view,
  onChanged: (i) => setState(() => view = i),
)

NativeSlider(
  value: volume,
  onChanged: (v) => setState(() => volume = v),
  onChangeEnd: save,
)

NativePopUpButton<Sort>(
  value: sort,
  onChanged: (v) => setState(() => sort = v),
  items: const [
    NativeMenuItem(title: 'Name', value: Sort.name),
    NativeMenuItem(title: 'Date Modified', value: Sort.date),
    NativeMenuDivider(),
    NativeMenuItem(title: 'Size', value: Sort.size),
  ],
)
```

If the parent does not rebuild with the new value by the next frame, the
native control goes back to the old one. Call `setState` before any `await`
in the callback, or the control flickers back and forth.

### Alerts and menus

```dart
final index = await showNativeAlert(
  context: context,
  title: 'Delete this item?',
  message: 'You cannot undo this action.',
  buttons: const [
    NativeAlertButton('Delete', destructive: true),
    NativeAlertButton('Cancel', isCancel: true),
  ],
);

GestureDetector(
  onSecondaryTapUp: (details) async {
    final action = await showNativeMenu<String>(
      context: context,
      globalPosition: details.globalPosition,
      items: const [
        NativeMenuItem(title: 'Copy', value: 'copy', symbol: 'doc.on.doc'),
        NativeMenuItem(title: 'Rename', value: 'rename'),
      ],
    );
  },
  child: row,
)
```

`showNativeAlert` returns the index of the pressed button, or -1 if the
alert closed without one. Both throw `UnsupportedError` off macOS, and `NativeMacosException` with code
`no_window` when the Flutter view is not in a window yet.

### Overlays

AppKit views take clicks anywhere Flutter has not painted, even under the
transparent barrier of a Flutter dialog. Block them while an overlay is open:

```dart
NativeInputBlocker(
  blocked: dialogOpen,
  child: page,
)
```

### Fallbacks and checks

```dart
NativeSwitch(
  value: on,
  onChanged: toggle,
  fallback: Switch(value: on, onChanged: toggle),
)

if (NativeMacos.hasLiquidGlass) { /* macOS 26 or later */ }
```

## Example

```sh
cd example
flutter run -d macos
```

## Limitations

These come from how Flutter embeds AppKit views today.

- `gestureRecognizers` do nothing on macOS. Native controls handle the mouse
  themselves, so a Flutter `GestureDetector` around one does not see its
  clicks.
- Tab focus does not move into native views. The controls do not take
  keyboard focus, so your Flutter shortcuts keep working, but they cannot be
  operated with the keyboard.
- Native views are not in the VoiceOver tree when Flutter semantics are on.
- Flutter blocks native input by the bounding box of what it paints, so a
  border or shadow over a native view can block the whole area.
- Clips other than rectangles, rounded rectangles, and ovals are ignored, and
  perspective transforms render wrongly.
- `BackdropFilter`, `ColorFiltered`, `ShaderMask`, and route transitions with
  image filters do not apply to native views. Native glass can sample Flutter
  pixels, but Flutter cannot sample native pixels.
- Each native view is created asynchronously and is blank for its first
  frame. Sizes start from an estimate and settle once AppKit reports the
  fitting size.
- Each native view with Flutter content above it costs one extra
  window-sized surface. Use native views for controls and navigation, not for
  long lists.
- Only the main Flutter view is supported; multi-window is still
  experimental in Flutter. `NativeToolbar` replaces any toolbar you set on
  that window yourself.

## Related packages

- [native_trend](https://pub.dev/packages/native_trend) picks pub.dev
  packages that render the latest platform design with native views, and
  writes the result for your AI coding assistant.

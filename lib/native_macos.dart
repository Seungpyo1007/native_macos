/// Real AppKit controls and Liquid Glass for Flutter on macOS.
///
/// The widgets embed native views with `AppKitView`, so macOS draws them.
/// On other platforms they show a Flutter fallback.
library;

export 'src/native_alert.dart';
export 'src/native_button.dart';
export 'src/native_checkbox.dart';
export 'src/native_glass_container.dart';
export 'src/native_input_blocker.dart';
export 'src/native_macos_exception.dart';
export 'src/native_menu.dart'
    show NativeMenuDivider, NativeMenuEntry, NativeMenuItem, showNativeMenu;
export 'src/native_popup_button.dart';
export 'src/native_progress_indicator.dart';
export 'src/native_segmented_control.dart';
export 'src/native_slider.dart';
export 'src/native_support.dart';
export 'src/native_switch.dart';
export 'src/native_toolbar.dart';
export 'src/native_types.dart';

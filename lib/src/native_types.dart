/// AppKit `NSControl.ControlSize`.
///
/// [extraLarge] needs macOS 26 and falls back to [large] before it.
enum NativeControlSize { mini, small, regular, large, extraLarge }

/// AppKit `NSTintProminence`: how strongly a control shows its tint.
///
/// Needs macOS 26; ignored before it.
enum NativeTintProminence { automatic, none, primary, secondary }

/// AppKit `NSControl.BorderShape`.
///
/// Needs macOS 26; ignored before it.
enum NativeBorderShape { automatic, capsule, roundedRectangle, circle }

/// `NSGlassEffectView.Style`.
///
/// [regular] is frosted: it blurs what is behind it and keeps text legible,
/// so large panels look much like a blur. [clear] is more transparent and
/// visibly bends the content behind its edges, the lens look of Liquid
/// Glass; use it over colorful content and keep text on it short.
enum NativeGlassStyle { regular, clear }

/// The bezel of a `NativeButton`.
///
/// [glass] needs macOS 26 and falls back to [push] before it.
enum NativeButtonStyle { automatic, push, glass, borderless }

/// The appearance of a `NativeProgressIndicator`.
enum NativeProgressStyle { bar, spinning }

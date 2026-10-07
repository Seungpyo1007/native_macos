/// An error reported by the native side of `native_macos`.
class NativeMacosException implements Exception {
  const NativeMacosException(this.message, {required this.code});

  /// What went wrong, in English.
  final String message;

  /// A stable code. Today the only one is `no_window`: the Flutter view is
  /// not in a window yet.
  final String code;

  @override
  String toString() => message;
}

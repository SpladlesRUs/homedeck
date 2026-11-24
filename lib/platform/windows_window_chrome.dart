// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Direct Win32 chrome/size changes for the HomeDeck runner HWND.
///
/// `window_manager` 0.7's native `getCurrent()`/`getAll()` often miss the stock
/// Flutter runner window on Windows (no HWND bind), so F11 became a Flutter-only
/// flag with `chromeChanged=false` on Ally. Find `FLUTTER_RUNNER_WIN32_WINDOW`
/// titled HomeDeck and toggle style/placement ourselves.
class WindowsWindowChrome {
  WindowsWindowChrome._();

  static const _gwlStyle = -16;
  static const _wsCaption = 0x00C00000;
  static const _wsThickframe = 0x00040000;
  static const _wsMinimizeBox = 0x00020000;
  static const _wsMaximizeBox = 0x00010000;
  static const _wsSysMenu = 0x00080000;
  static const _wsPopup = 0x80000000;
  static const _wsVisible = 0x10000000;
  static const _swpFramechanged = 0x0020;
  static const _swpShowwindow = 0x0040;
  static const _monitorDefaultToNearest = 2;

  static int? _restoreStyle;
  static _Rect? _restoreRect;

  static FindWindowWDart? _findWindow;
  static GetWindowLongPtrWDart? _getStyle;
  static SetWindowLongPtrWDart? _setStyle;
  static GetWindowRectDart? _getRect;
  static SetWindowPosDart? _setPos;
  static MonitorFromWindowDart? _monitorFromWindow;
  static GetMonitorInfoWDart? _getMonitorInfo;
  static bool _bindFailed = false;

  /// Applies fullscreen (frameless + cover monitor) or restores prior chrome.
  /// Returns true when a HomeDeck HWND was found and updated.
  static bool apply({required bool fullscreen, required bool borderless}) {
    if (!Platform.isWindows) {
      return false;
    }
    if (!_bind()) {
      return false;
    }
    final hwnd = _findHomeDeck();
    if (hwnd == nullptr || hwnd.address == 0) {
      return false;
    }
    if (fullscreen) {
      return _enterFullscreen(hwnd);
    }
    return _exitFullscreen(hwnd, borderless: borderless);
  }

  static bool _enterFullscreen(HWND hwnd) {
    _restoreStyle ??= _getStyle!(hwnd, _gwlStyle);
    final rect = calloc<RECT>();
    try {
      if (_getRect!(hwnd, rect) != 0) {
        _restoreRect ??= _Rect(
          left: rect.ref.left,
          top: rect.ref.top,
          right: rect.ref.right,
          bottom: rect.ref.bottom,
        );
      }
    } finally {
      calloc.free(rect);
    }

    final monitor = _monitorFromWindow!(hwnd, _monitorDefaultToNearest);
    final info = calloc<MONITORINFO>();
    try {
      info.ref.cbSize = sizeOf<MONITORINFO>();
      late final int left;
      late final int top;
      late final int right;
      late final int bottom;
      if (monitor.address != 0 && _getMonitorInfo!(monitor, info) != 0) {
        left = info.ref.rcMonitor.left;
        top = info.ref.rcMonitor.top;
        right = info.ref.rcMonitor.right;
        bottom = info.ref.rcMonitor.bottom;
      } else {
        // Fallback: keep current origin, force a larger client than Ally's
        // 1280×720 harness window so chromeChanged is observable.
        final current = _restoreRect;
        left = current?.left ?? 0;
        top = current?.top ?? 0;
        right = left + 1920;
        bottom = top + 1080;
      }

      _setStyle!(hwnd, _gwlStyle, _wsPopup | _wsVisible);
      _setPos!(
        hwnd,
        nullptr,
        left,
        top,
        right - left,
        bottom - top,
        _swpFramechanged | _swpShowwindow,
      );
      return true;
    } finally {
      calloc.free(info);
    }
  }

  static bool _exitFullscreen(HWND hwnd, {required bool borderless}) {
    final style = _restoreStyle;
    final rect = _restoreRect;
    if (style != null) {
      var next = style;
      if (borderless) {
        next &= ~(_wsCaption |
            _wsThickframe |
            _wsMinimizeBox |
            _wsMaximizeBox |
            _wsSysMenu);
      }
      _setStyle!(hwnd, _gwlStyle, next);
    }
    if (rect != null) {
      _setPos!(
        hwnd,
        nullptr,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        _swpFramechanged | _swpShowwindow,
      );
    } else {
      _setPos!(
        hwnd,
        nullptr,
        0,
        0,
        1280,
        800,
        _swpFramechanged | _swpShowwindow,
      );
    }
    return true;
  }

  static HWND _findHomeDeck() {
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    final title = 'HomeDeck'.toNativeUtf16();
    try {
      return _findWindow!(className, title);
    } finally {
      calloc.free(className);
      calloc.free(title);
    }
  }

  static bool _bind() {
    if (_findWindow != null) {
      return true;
    }
    if (_bindFailed) {
      return false;
    }
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      _findWindow = user32
          .lookup<NativeFunction<FindWindowWNative>>('FindWindowW')
          .asFunction();
      try {
        _getStyle = user32
            .lookup<NativeFunction<GetWindowLongPtrWNative>>(
              'GetWindowLongPtrW',
            )
            .asFunction();
        _setStyle = user32
            .lookup<NativeFunction<SetWindowLongPtrWNative>>(
              'SetWindowLongPtrW',
            )
            .asFunction();
      } catch (_) {
        _getStyle = user32
            .lookup<NativeFunction<GetWindowLongPtrWNative>>('GetWindowLongW')
            .asFunction();
        _setStyle = user32
            .lookup<NativeFunction<SetWindowLongPtrWNative>>('SetWindowLongW')
            .asFunction();
      }
      _getRect = user32
          .lookup<NativeFunction<GetWindowRectNative>>('GetWindowRect')
          .asFunction();
      _setPos = user32
          .lookup<NativeFunction<SetWindowPosNative>>('SetWindowPos')
          .asFunction();
      _monitorFromWindow = user32
          .lookup<NativeFunction<MonitorFromWindowNative>>('MonitorFromWindow')
          .asFunction();
      _getMonitorInfo = user32
          .lookup<NativeFunction<GetMonitorInfoWNative>>('GetMonitorInfoW')
          .asFunction();
      return true;
    } catch (_) {
      _bindFailed = true;
      return false;
    }
  }
}

class _Rect {
  const _Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
}

typedef HWND = Pointer<Void>;
typedef HMONITOR = Pointer<Void>;

final class RECT extends Struct {
  @Int32()
  external int left;

  @Int32()
  external int top;

  @Int32()
  external int right;

  @Int32()
  external int bottom;
}

final class MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;

  external RECT rcMonitor;

  external RECT rcWork;

  @Uint32()
  external int dwFlags;
}

typedef FindWindowWNative = HWND Function(
  Pointer<Utf16> lpClassName,
  Pointer<Utf16> lpWindowName,
);
typedef FindWindowWDart = HWND Function(
  Pointer<Utf16> lpClassName,
  Pointer<Utf16> lpWindowName,
);

typedef GetWindowLongPtrWNative = IntPtr Function(HWND hWnd, Int32 nIndex);
typedef GetWindowLongPtrWDart = int Function(HWND hWnd, int nIndex);

typedef SetWindowLongPtrWNative = IntPtr Function(
  HWND hWnd,
  Int32 nIndex,
  IntPtr dwNewLong,
);
typedef SetWindowLongPtrWDart = int Function(
  HWND hWnd,
  int nIndex,
  int dwNewLong,
);

typedef GetWindowRectNative = Int32 Function(HWND hWnd, Pointer<RECT> lpRect);
typedef GetWindowRectDart = int Function(HWND hWnd, Pointer<RECT> lpRect);

typedef SetWindowPosNative = Int32 Function(
  HWND hWnd,
  HWND hWndInsertAfter,
  Int32 X,
  Int32 Y,
  Int32 cx,
  Int32 cy,
  Uint32 uFlags,
);
typedef SetWindowPosDart = int Function(
  HWND hWnd,
  HWND hWndInsertAfter,
  int X,
  int Y,
  int cx,
  int cy,
  int uFlags,
);

typedef MonitorFromWindowNative = HMONITOR Function(
  HWND hwnd,
  Uint32 dwFlags,
);
typedef MonitorFromWindowDart = HMONITOR Function(HWND hwnd, int dwFlags);

typedef GetMonitorInfoWNative = Int32 Function(
  HMONITOR hMonitor,
  Pointer<MONITORINFO> lpmi,
);
typedef GetMonitorInfoWDart = int Function(
  HMONITOR hMonitor,
  Pointer<MONITORINFO> lpmi,
);

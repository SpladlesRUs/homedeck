// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Win32 ShellExecuteW launch. More reliable than `cmd /c start` from a
/// Flutter runner (Ally Phase2: Enter never spawned notepad).
class WindowsShell {
  WindowsShell._();

  static ShellExecuteWDart? _shellExecute;
  static bool _bindFailed = false;

  static const _swShownormal = 1;

  /// Opens [path] (.exe, .lnk, or URI) with optional [arguments].
  /// Returns false when ShellExecute is unavailable or returns an error.
  static bool open(String path, {List<String> arguments = const []}) {
    if (!Platform.isWindows) {
      return false;
    }
    final fn = _resolve();
    if (fn == null) {
      return false;
    }
    final file = path.toNativeUtf16();
    final params = arguments.isEmpty
        ? nullptr
        : WindowsShell._quoteArgs(arguments).toNativeUtf16();
    final operation = 'open'.toNativeUtf16();
    try {
      final result = fn(
        nullptr,
        operation,
        file,
        params,
        nullptr,
        _swShownormal,
      );
      // Per MSDN, values > 32 indicate success.
      return result > 32;
    } finally {
      calloc.free(file);
      calloc.free(operation);
      if (params != nullptr) {
        calloc.free(params);
      }
    }
  }

  static ShellExecuteWDart? _resolve() {
    if (_shellExecute != null || _bindFailed) {
      return _shellExecute;
    }
    try {
      final lib = DynamicLibrary.open('shell32.dll');
      _shellExecute = lib
          .lookup<NativeFunction<ShellExecuteWNative>>('ShellExecuteW')
          .asFunction();
    } catch (_) {
      _bindFailed = true;
      return null;
    }
    return _shellExecute;
  }

  static String _quoteArgs(List<String> arguments) {
    return arguments.map((arg) {
      if (arg.contains(' ') || arg.contains('"')) {
        return '"${arg.replaceAll('"', '\\"')}"';
      }
      return arg;
    }).join(' ');
  }
}

typedef ShellExecuteWNative = IntPtr Function(
  Pointer<Void> hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  Int32 nShowCmd,
);

typedef ShellExecuteWDart = int Function(
  Pointer<Void> hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  int nShowCmd,
);

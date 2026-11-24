#ifndef RUNNER_HOMEDECK_WIN32_H_
#define RUNNER_HOMEDECK_WIN32_H_

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>

#include "win32_window.h"

// Native Win32 helpers for Ally Phase2: launch targets and toggle chrome
// using the real runner HWND (Dart FFI FindWindow / ShellExecute did not
// change chrome or spawn notepad on device at tip 2417533).
class HomedeckWin32 {
 public:
  HomedeckWin32() = default;

  void Register(flutter::BinaryMessenger* messenger, Win32Window* window);

  // Absolute fullscreen chrome. Returns true when the HWND was updated.
  bool SetFullscreen(bool fullscreen);

  bool IsFullscreen() const { return fullscreen_; }

  // ShellExecuteW the path (.exe / .lnk / URI). Returns true on success.
  static bool Launch(const std::wstring& path, const std::wstring& args);

 private:
  void NotifyFullscreen();

  Win32Window* window_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool fullscreen_ = false;
  LONG_PTR restore_style_ = 0;
  RECT restore_rect_{};
  bool has_restore_ = false;
};

#endif  // RUNNER_HOMEDECK_WIN32_H_

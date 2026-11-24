#ifndef RUNNER_HOMEDECK_WIN32_H_
#define RUNNER_HOMEDECK_WIN32_H_

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "win32_window.h"

// Native Win32 helpers for Ally: launch, F11 chrome, and PE/.lnk icon
// extraction. Dart-only FFI failed on device for launch/chrome (2417533)
// and left icons\ empty for M2 extract (8715ce4) — runner owns HWND/GDI+.
class HomedeckWin32 {
 public:
  HomedeckWin32() = default;

  void Register(flutter::BinaryMessenger* messenger, Win32Window* window);

  // Absolute fullscreen chrome. Returns true when the HWND was updated.
  bool SetFullscreen(bool fullscreen);

  bool IsFullscreen() const { return fullscreen_; }

  // ShellExecuteW the path (.exe / .lnk / URI). Returns true on success.
  static bool Launch(const std::wstring& path, const std::wstring& args);

  // Extract associated / PE icon as PNG bytes (empty optional on failure).
  static std::optional<std::vector<uint8_t>> ExtractIconPng(
      const std::wstring& path, int size);

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

#ifndef RUNNER_HOMEDECK_WIN32_H_
#define RUNNER_HOMEDECK_WIN32_H_

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "win32_window.h"

// Custom message: background extractIcon finished; LPARAM owns the payload.
#ifndef WM_HOMEDECK_ICON_DONE
#define WM_HOMEDECK_ICON_DONE (WM_APP + 0x4D44)  // 'MD'
#endif

// Native Win32 helpers for Ally: launch, F11 chrome, and PE/.lnk icon
// extraction. Sync MethodChannel extract on the platform thread deadlocked
// the message pump at f9b1d14 (icons\ stayed empty). extractIcon now runs on
// a worker thread and completes via WM_HOMEDECK_ICON_DONE.
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

  // Durable CreateFile write for IconCache dual-write to AppData.
  static bool WriteFileBytes(const std::wstring& path,
                             const std::vector<uint8_t>& bytes);

  // Classic GetOpenFileName titled "Open" (Ally FindWindow / SendKeys) with
  // optional OK label "Add to HomeDeck". Empty string when cancelled.
  // HOMEDECK_ADD_PATH env bypasses the modal with a fixed path.
  std::wstring PickOpenFile(const std::wstring& filter_label,
                            const std::wstring& extensions,
                            const std::wstring& ok_label);

  // Drain a WM_HOMEDECK_ICON_DONE posted from the extract worker.
  // Returns true when the message was handled.
  bool HandleIconDone(LPARAM lparam);

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

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

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys `a` (or a real A key)
// should open the classic FindWindow-able Open dialog on the UI thread.
#ifndef WM_HOMEDECK_ADD
#define WM_HOMEDECK_ADD (WM_APP + 0x41)
#endif

// Native Win32 helpers for Ally: launch, F11 chrome, PE/.lnk icon extraction,
// and classic GetOpenFileName for Phase2 FindWindow.
//
// Ally SendKeys land on the Flutter view child — Flutter Shortcuts often never
// see `a`, so pickOpenFile never ran and the harness logged "Open dialog not
// found". WH_KEYBOARD_LL posts WM_HOMEDECK_ADD; the UI thread shows OFN titled
// exactly "Open" (class #32770), then notifies Dart via addPickedPath.
class HomedeckWin32 {
 public:
  HomedeckWin32() = default;
  ~HomedeckWin32();

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

  // Classic GetOpenFileName titled "Open" (Ally FindWindow class #32770).
  // OK button label defaults to "Add to HomeDeck". Empty when cancelled.
  // HOMEDECK_ADD_PATH env bypasses the modal with a fixed path.
  std::wstring PickOpenFile(const std::wstring& filter_label,
                            const std::wstring& extensions,
                            const std::wstring& ok_label);

  // UI-thread handler for WM_HOMEDECK_ADD: show classic Open (or honor
  // HOMEDECK_ADD_PATH) then notify Dart via addPickedPath.
  void HandleAddKey();

  // Drain a WM_HOMEDECK_ICON_DONE posted from the extract worker.
  // Returns true when the message was handled.
  bool HandleIconDone(LPARAM lparam);

 private:
  void NotifyFullscreen();
  void NotifyPickedPath(const std::wstring& path);
  void InstallHook();
  void RemoveHook();
  bool IsOurForeground() const;
  static bool ModifierHeld();

  static LRESULT CALLBACK LowLevelKeyboardProc(int n_code, WPARAM w_param,
                                               LPARAM l_param);

  Win32Window* window_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool fullscreen_ = false;
  LONG_PTR restore_style_ = 0;
  RECT restore_rect_{};
  bool has_restore_ = false;
  HHOOK keyboard_hook_ = nullptr;
  // True while GetOpenFileName is modal — do not steal A from OFN.
  bool picking_file_ = false;

  static HomedeckWin32* instance_;
};

#endif  // RUNNER_HOMEDECK_WIN32_H_

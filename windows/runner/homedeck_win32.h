#ifndef RUNNER_HOMEDECK_WIN32_H_
#define RUNNER_HOMEDECK_WIN32_H_

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>

#include "win32_window.h"

// Native Win32 helpers for Ally Phase2.
//
// Ally's harness drives keys with WScript.Shell SendKeys after AppActivate —
// those land on the Flutter view child, so FlutterWindow::MessageHandler never
// sees WM_KEYDOWN. A low-level keyboard hook catches F11 / Enter while our
// process is foreground and applies chrome / ShellExecute without Dart.
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

  // Launch the path Dart last reported as focused (Enter / A).
  bool LaunchFocused();

  // Remember the focused tile launch target for the keyboard hook.
  void SetFocusedLaunch(const std::wstring& path, const std::wstring& args);

  // Ask Dart to launch the focused tile when [focused_path_] is empty.
  void RequestDartLaunch();

  // Enter: ShellExecute mirrored path, else ask Dart. Always returns true
  // while HomeDeck should own the key (caller still checks foreground).
  bool HandleEnter();

  // Classic GetOpenFileName titled "Open" (Ally FindWindow) with optional
  // OK label "Add to HomeDeck". Returns empty string when cancelled.
  std::wstring PickOpenFile(const std::wstring& filter_label,
                            const std::wstring& extensions,
                            const std::wstring& ok_label);

 private:
  void NotifyFullscreen();
  void InstallHook();
  void RemoveHook();
  bool IsOurForeground() const;

  static LRESULT CALLBACK LowLevelKeyboardProc(int n_code, WPARAM w_param,
                                               LPARAM l_param);

  Win32Window* window_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool fullscreen_ = false;
  LONG_PTR restore_style_ = 0;
  RECT restore_rect_{};
  bool has_restore_ = false;
  std::wstring focused_path_;
  std::wstring focused_args_;
  HHOOK keyboard_hook_ = nullptr;
  // True while GetOpenFileName is modal — do not steal Enter/F11 from OFN.
  bool picking_file_ = false;

  static HomedeckWin32* instance_;
};

#endif  // RUNNER_HOMEDECK_WIN32_H_

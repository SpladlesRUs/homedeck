#ifndef RUNNER_HOMEDECK_WIN32_H_
#define RUNNER_HOMEDECK_WIN32_H_

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <atomic>
#include <cstdint>
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

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys `s` (or a real S key)
// should run Steam library discover → Library import (no Settings UIA).
#ifndef WM_HOMEDECK_SCAN_STEAM
#define WM_HOMEDECK_SCAN_STEAM (WM_APP + 0x53)
#endif

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys `p` (or a real P key)
// should run Start Menu Programs discover → Library import (no Settings UIA).
#ifndef WM_HOMEDECK_SCAN_START_MENU
#define WM_HOMEDECK_SCAN_START_MENU (WM_APP + 0x50)
#endif

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys `r` (or a real R key)
// should run ROM-folder discover → Library import (no Settings UIA).
#ifndef WM_HOMEDECK_SCAN_ROMS
#define WM_HOMEDECK_SCAN_ROMS (WM_APP + 0x52)
#endif

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys `h` (or a real H key)
// should pin the focused Library record onto Home (same as UI Add to Home).
#ifndef WM_HOMEDECK_PIN_HOME
#define WM_HOMEDECK_PIN_HOME (WM_APP + 0x48)
#endif

// Posted by the WH_KEYBOARD_LL hook when Ally SendKeys Delete/Backspace
// should unpin (Home) or ask to remove (Library) the focused tile.
#ifndef WM_HOMEDECK_REMOVE
#define WM_HOMEDECK_REMOVE (WM_APP + 0x2E)  // VK_DELETE
#endif

// Posted while remove-armed (Library confirm pending): Enter must confirm
// remove via Dart, not ShellExecute the prior mirrored path.
#ifndef WM_HOMEDECK_CONFIRM
#define WM_HOMEDECK_CONFIRM (WM_APP + 0x0D)  // VK_RETURN
#endif

// Posted by the game-exit watcher thread when a tracked .exe/.lnk process
// terminates. WPARAM/LPARAM carry the 64-bit watch generation.
#ifndef WM_HOMEDECK_GAME_EXIT
#define WM_HOMEDECK_GAME_EXIT (WM_APP + 0x47)  // 'G'
#endif

// Native Win32 helpers for Ally: launch, F11 chrome, Enter→focused path,
// PE/.lnk icon extraction, classic GetOpenFileName for Phase2 FindWindow,
// bare S → Steam library scan, bare P → Start Menu Programs scan, bare R →
// ROM-folder scan, bare H → pin focused Library tile to Home, and bare
// Delete/Backspace → unpin / Library remove.
//
// Ally SendKeys land on the Flutter view child — Flutter Shortcuts often never
// see `a`, so pickOpenFile never ran and the harness logged "Open dialog not
// found". WH_KEYBOARD_LL posts WM_HOMEDECK_ADD; the UI thread shows OFN titled
// exactly "Open" (class #32770), then notifies Dart via addPickedPath. Bare
// `s` posts WM_HOMEDECK_SCAN_STEAM → Dart `scanSteam` (Settings scan without
// opening the overlay). Bare `p` posts WM_HOMEDECK_SCAN_START_MENU → Dart
// `scanStartMenu`. Bare `r` posts WM_HOMEDECK_SCAN_ROMS → Dart `scanRoms`.
// Bare `h` posts WM_HOMEDECK_PIN_HOME → Dart `pinFocusedToHome` (UI Add to
// Home without menu UIA). Bare Delete/Backspace posts WM_HOMEDECK_REMOVE →
// Dart `removeFocused` (same as RemoveFocusedIntent / `_requestRemove`).
// While Library remove confirm is pending, Enter posts WM_HOMEDECK_CONFIRM
// (not ShellExecute) until Dart clears remove-armed. The same hook handles
// F11 chrome and Enter→mirrored path (with a Dart launchFocused fallback
// when the mirror is empty).
class HomedeckWin32 {
 public:
  HomedeckWin32() = default;
  ~HomedeckWin32();

  void Register(flutter::BinaryMessenger* messenger, Win32Window* window);

  // Absolute fullscreen chrome. Returns true when the HWND was updated.
  bool SetFullscreen(bool fullscreen);

  bool IsFullscreen() const { return fullscreen_; }

  // ShellExecuteEx the path (.exe / .lnk / URI). Returns true on success.
  // Local .exe/.lnk: tracks the process handle and restores HomeDeck on exit
  // when restore-on-exit is enabled. Store URIs (steam:// etc.) are
  // best-effort launch only — no process wait / Steam overlay hooks.
  bool Launch(const std::wstring& path, const std::wstring& args);

  // Launch the path Dart last reported as focused (Enter / A).
  bool LaunchFocused();

  // Remember the focused tile launch target for the keyboard hook.
  void SetFocusedLaunch(const std::wstring& path, const std::wstring& args);

  // Mirror Dart WindowPrefs.fullscreenOnLaunch (default true).
  void SetFullscreenOnLaunch(bool enabled);

  bool FullscreenOnLaunch() const { return fullscreen_on_launch_; }

  // Mirror Dart WindowPrefs.restoreOnExit (default true).
  void SetRestoreOnExit(bool enabled);

  bool RestoreOnExit() const { return restore_on_exit_; }

  // UI-thread handler for WM_HOMEDECK_GAME_EXIT: leave launch fullscreen
  // (when we entered it) and bring HomeDeck to the foreground.
  void HandleGameExit(uint64_t generation);

  // Ask Dart to launch the focused tile when [focused_path_] is empty.
  void RequestDartLaunch();

  // Enter: ShellExecute mirrored path, else ask Dart. Always returns true
  // while HomeDeck should own the key (caller still checks foreground).
  bool HandleEnter();

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

  // UI-thread handler for WM_HOMEDECK_SCAN_STEAM: ask Dart to run the same
  // Steam discover → importDiscovered path as Settings → Scan Steam library.
  void HandleScanSteamKey();

  // UI-thread handler for WM_HOMEDECK_SCAN_START_MENU: ask Dart to run Start
  // Menu Programs discover → importDiscovered (Settings → Scan Start Menu).
  void HandleScanStartMenuKey();

  // UI-thread handler for WM_HOMEDECK_SCAN_ROMS: ask Dart to run ROM-folder
  // discover → importRoms (Settings → Scan ROM folder).
  void HandleScanRomsKey();

  // UI-thread handler for WM_HOMEDECK_PIN_HOME: ask Dart to pin the focused
  // Library record onto Home (same as UI Add to Home).
  void HandlePinHomeKey();

  // UI-thread handler for WM_HOMEDECK_REMOVE: ask Dart to unpin (Home) or
  // show Library remove confirm (same as RemoveFocusedIntent).
  void HandleRemoveKey();

  // UI-thread handler for WM_HOMEDECK_CONFIRM: ask Dart `_handleConfirm`
  // (Library remove Enter) without ShellExecute.
  void HandleConfirmKey();

  // Ally Delete→Enter: while armed, Enter confirms remove instead of launch.
  void SetRemoveArmed(bool armed);

  bool RemoveArmed() const { return remove_armed_; }

  // Drain a WM_HOMEDECK_ICON_DONE posted from the extract worker.
  // Returns true when the message was handled.
  bool HandleIconDone(LPARAM lparam);

 private:
  void NotifyFullscreen();
  void NotifyGameExited();
  void NotifyPickedPath(const std::wstring& path);
  void InstallHook();
  void RemoveHook();
  bool IsOurForeground() const;
  void StartWatchingProcess(HANDLE process);
  void BringHomeDeckToForeground();
  static bool ModifierHeld();

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
  // Default ON — console feel; Dart mirrors Settings via setFullscreenOnLaunch.
  bool fullscreen_on_launch_ = true;
  // Default ON — return to launcher when a tracked local process exits.
  bool restore_on_exit_ = true;
  // True while WaitForSingleObject is pending for the latest local launch.
  bool watching_active_ = false;
  // True when SetFullscreen(true) ran while watching_active_ (fullscreen-on-
  // launch for this session — not a prior standalone F11).
  bool entered_fullscreen_for_launch_ = false;
  // Bumped on each new watch / destructor so stale exit posts are ignored.
  std::atomic<uint64_t> watch_generation_{0};
  HHOOK keyboard_hook_ = nullptr;
  // True while GetOpenFileName is modal — do not steal Enter/F11/A from OFN.
  bool picking_file_ = false;
  // True after bare Delete/Backspace until Dart clears (Home unpin done, or
  // Library remove confirmed/cancelled). Suppresses Enter→ShellExecute.
  bool remove_armed_ = false;

  static HomedeckWin32* instance_;
};

#endif  // RUNNER_HOMEDECK_WIN32_H_

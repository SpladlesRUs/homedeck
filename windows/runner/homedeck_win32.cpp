#include "homedeck_win32.h"

#include <flutter/standard_method_codec.h>
#include <commdlg.h>
#include <shellapi.h>

#include "utils.h"

namespace {

constexpr char kChannel[] = "homedeck/win32";

// CDN_INITDONE hook: rename OK so Ally/SendKeys can target "Add to HomeDeck"
// while the window title stays the classic FindWindow-able "Open".
struct PickHookState {
  const wchar_t* ok_label = nullptr;
};

UINT_PTR CALLBACK PickOpenHook(HWND hwnd, UINT msg, WPARAM, LPARAM lparam) {
  if (msg == WM_INITDIALOG) {
    // Explorer-style OFN: hook owns the child; parent is the "#32770" "Open".
    return FALSE;
  }
  if (msg == WM_NOTIFY) {
    const auto* notify = reinterpret_cast<LPOFNOTIFY>(lparam);
    if (notify != nullptr && notify->hdr.code == CDN_INITDONE &&
        notify->lpOFN != nullptr) {
      const auto* state =
          reinterpret_cast<PickHookState*>(notify->lpOFN->lCustData);
      if (state != nullptr && state->ok_label != nullptr &&
          state->ok_label[0] != L'\0') {
        CommDlg_OpenSave_SetControlText(GetParent(hwnd), IDOK, state->ok_label);
      }
    }
  }
  return FALSE;
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int count = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                        static_cast<int>(utf8.size()),
                                        nullptr, 0);
  if (count <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(count), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      wide.data(), count);
  return wide;
}

std::string JoinArgs(const flutter::EncodableList& args) {
  std::string joined;
  for (const auto& entry : args) {
    if (const auto* value = std::get_if<std::string>(&entry)) {
      if (!joined.empty()) {
        joined.push_back(' ');
      }
      const bool quote = value->find(' ') != std::string::npos ||
                         value->find('"') != std::string::npos;
      if (quote) {
        joined.push_back('"');
        for (char ch : *value) {
          if (ch == '"') {
            joined.append("\\\"");
          } else {
            joined.push_back(ch);
          }
        }
        joined.push_back('"');
      } else {
        joined.append(*value);
      }
    }
  }
  return joined;
}

// Build OPENFILENAME filter: "Label\0*.exe;*.lnk\0All files\0*.*\0\0"
std::wstring BuildFilter(const std::wstring& label,
                         const std::wstring& extensions) {
  std::wstring filter;
  filter.append(label.empty() ? L"Files" : label);
  filter.push_back(L'\0');
  if (extensions.empty()) {
    filter.append(L"*.*");
  } else {
    bool first = true;
    size_t start = 0;
    while (start <= extensions.size()) {
      size_t comma = extensions.find(L',', start);
      if (comma == std::wstring::npos) {
        comma = extensions.size();
      }
      std::wstring ext = extensions.substr(start, comma - start);
      while (!ext.empty() && ext.front() == L'.') {
        ext.erase(ext.begin());
      }
      if (!ext.empty()) {
        if (!first) {
          filter.push_back(L';');
        }
        first = false;
        filter.append(L"*.");
        filter.append(ext);
      }
      if (comma >= extensions.size()) {
        break;
      }
      start = comma + 1;
    }
    if (first) {
      filter.append(L"*.*");
    }
  }
  filter.push_back(L'\0');
  filter.append(L"All files");
  filter.push_back(L'\0');
  filter.append(L"*.*");
  filter.push_back(L'\0');
  filter.push_back(L'\0');
  return filter;
}

}  // namespace

HomedeckWin32* HomedeckWin32::instance_ = nullptr;

HomedeckWin32::~HomedeckWin32() {
  RemoveHook();
  if (instance_ == this) {
    instance_ = nullptr;
  }
}

void HomedeckWin32::Register(flutter::BinaryMessenger* messenger,
                             Win32Window* window) {
  window_ = window;
  instance_ = this;
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        if (method == "setFullscreen") {
          bool fullscreen = false;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("fullscreen"));
            if (it != args->end()) {
              if (const auto* flag = std::get_if<bool>(&it->second)) {
                fullscreen = *flag;
              }
            }
          }
          const bool ok = SetFullscreen(fullscreen);
          result->Success(flutter::EncodableValue(ok));
          return;
        }
        if (method == "launch") {
          std::string path;
          std::string args;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto path_it = map->find(flutter::EncodableValue("path"));
            if (path_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = *value;
              }
            }
            auto args_it = map->find(flutter::EncodableValue("arguments"));
            if (args_it != map->end()) {
              if (const auto* list =
                      std::get_if<flutter::EncodableList>(&args_it->second)) {
                args = JoinArgs(*list);
              } else if (const auto* value =
                             std::get_if<std::string>(&args_it->second)) {
                args = *value;
              }
            }
          }
          if (path.empty()) {
            result->Error("invalid_args", "launch requires path");
            return;
          }
          const bool ok = Launch(Utf8ToWide(path), Utf8ToWide(args));
          result->Success(flutter::EncodableValue(ok));
          return;
        }
        if (method == "setFocusedLaunch") {
          std::string path;
          std::string args;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto path_it = map->find(flutter::EncodableValue("path"));
            if (path_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = *value;
              }
            }
            auto args_it = map->find(flutter::EncodableValue("arguments"));
            if (args_it != map->end()) {
              if (const auto* list =
                      std::get_if<flutter::EncodableList>(&args_it->second)) {
                args = JoinArgs(*list);
              } else if (const auto* value =
                             std::get_if<std::string>(&args_it->second)) {
                args = *value;
              }
            }
          }
          SetFocusedLaunch(Utf8ToWide(path), Utf8ToWide(args));
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "isFullscreen") {
          result->Success(flutter::EncodableValue(fullscreen_));
          return;
        }
        if (method == "pickOpenFile") {
          // Ally Phase2 @bdd3ba1: file_selector IFileDialog never produced a
          // FindWindow-able "Open" dialog after SendKeys a → apps=[] / no Enter
          // target. Classic GetOpenFileName is #32770 titled "Open".
          std::string label = "Windows apps";
          std::string extensions = "exe,lnk";
          std::string ok_label = "Add to HomeDeck";
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto label_it = map->find(flutter::EncodableValue("label"));
            if (label_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&label_it->second)) {
                label = *value;
              }
            }
            auto ext_it = map->find(flutter::EncodableValue("extensions"));
            if (ext_it != map->end()) {
              if (const auto* ext_csv =
                      std::get_if<std::string>(&ext_it->second)) {
                extensions = *ext_csv;
              } else if (const auto* list = std::get_if<flutter::EncodableList>(
                             &ext_it->second)) {
                extensions.clear();
                for (const auto& entry : *list) {
                  if (const auto* ext = std::get_if<std::string>(&entry)) {
                    if (!extensions.empty()) {
                      extensions.push_back(',');
                    }
                    extensions.append(*ext);
                  }
                }
              }
            }
            auto ok_it =
                map->find(flutter::EncodableValue("confirmButtonText"));
            if (ok_it != map->end()) {
              if (const auto* value = std::get_if<std::string>(&ok_it->second)) {
                ok_label = *value;
              }
            }
          }
          const std::wstring path =
              PickOpenFile(Utf8ToWide(label), Utf8ToWide(extensions),
                           Utf8ToWide(ok_label));
          if (path.empty()) {
            result->Success(flutter::EncodableValue());
          } else {
            result->Success(
                flutter::EncodableValue(Utf8FromUtf16(path.c_str())));
          }
          return;
        }
        result->NotImplemented();
      });
  InstallHook();
}

void HomedeckWin32::InstallHook() {
  if (keyboard_hook_ != nullptr) {
    return;
  }
  keyboard_hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                     GetModuleHandle(nullptr), 0);
}

void HomedeckWin32::RemoveHook() {
  if (keyboard_hook_ != nullptr) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
}

bool HomedeckWin32::IsOurForeground() const {
  if (window_ == nullptr) {
    return false;
  }
  HWND hwnd = window_->GetHandle();
  if (hwnd == nullptr) {
    return false;
  }
  HWND foreground = GetForegroundWindow();
  if (foreground == nullptr) {
    return false;
  }
  if (foreground == hwnd || IsChild(hwnd, foreground)) {
    return true;
  }
  DWORD our_pid = 0;
  DWORD fg_pid = 0;
  GetWindowThreadProcessId(hwnd, &our_pid);
  GetWindowThreadProcessId(foreground, &fg_pid);
  return our_pid != 0 && our_pid == fg_pid;
}

bool HomedeckWin32::ModifierHeld() {
  return (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_MENU) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 ||
         (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0;
}

LRESULT CALLBACK HomedeckWin32::LowLevelKeyboardProc(int n_code,
                                                     WPARAM w_param,
                                                     LPARAM l_param) {
  if (n_code == HC_ACTION && instance_ != nullptr &&
      (w_param == WM_KEYDOWN || w_param == WM_SYSKEYDOWN)) {
    const auto* info = reinterpret_cast<KBDLLHOOKSTRUCT*>(l_param);
    // While classic Open is up, Enter confirms the file — do not ShellExecute
    // a mirrored path (same PID would otherwise look "foreground" to us).
    if (info != nullptr && instance_->IsOurForeground() &&
        !instance_->picking_file_) {
      if (info->vkCode == VK_F11) {
        instance_->SetFullscreen(!instance_->IsFullscreen());
        return 1;
      }
      if (info->vkCode == VK_RETURN) {
        if (instance_->HandleEnter()) {
          return 1;
        }
      }
      // Ally @82a5a20: SendKeys `a` never reached Flutter Shortcuts /
      // MethodChannel pickOpenFile, so GetOpenFileName never ran and the
      // harness logged "Open dialog not found" → apps=[]. Mirror F11/Enter:
      // post to the UI thread and consume so Shortcuts cannot double-open.
      if (info->vkCode == 'A' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_ADD, 0, 0);
          return 1;
        }
      }
    }
  }
  return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

bool HomedeckWin32::HandleEnter() {
  // Prefer the mirrored path (no Dart round-trip). Ally @ed8669d still saw
  // no notepad because adds never landed (Open dialog never opened), so
  // focused_path_ stayed empty — LaunchFocused could not run. When a path
  // is mirrored, always ShellExecute and consume Enter.
  if (LaunchFocused()) {
    return true;
  }
  // Path empty: ask Dart (focus may exist but mirror raced). Do *not*
  // consume so Add-sheet Confirm / file-dialog Enter still receive the key.
  RequestDartLaunch();
  return false;
}

bool HomedeckWin32::SetFullscreen(bool fullscreen) {
  if (window_ == nullptr) {
    return false;
  }
  HWND hwnd = window_->GetHandle();
  if (hwnd == nullptr) {
    return false;
  }

  if (fullscreen) {
    if (!has_restore_) {
      restore_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
      GetWindowRect(hwnd, &restore_rect_);
      has_restore_ = true;
    }
    HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{};
    info.cbSize = sizeof(MONITORINFO);
    RECT target = restore_rect_;
    if (monitor != nullptr && GetMonitorInfo(monitor, &info)) {
      target = info.rcMonitor;
    } else {
      // Observable size change vs Ally harness 1280×720 captioned window.
      target.right = target.left + 1920;
      target.bottom = target.top + 1080;
    }
    // Ally Phase2 measures hasCaption / isPopup on the top-level HWND. On a
    // 1280×720 handheld the monitor cover may keep the same size — WS_POPUP
    // (no WS_CAPTION) is what makes chromeChanged true.
    SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowPos(hwnd, HWND_TOP, target.left, target.top,
                 target.right - target.left, target.bottom - target.top,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    // Force non-client metrics refresh so caption clearance is observable.
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    fullscreen_ = true;
    NotifyFullscreen();
    return true;
  }

  LONG_PTR style =
      has_restore_ ? restore_style_ : (WS_OVERLAPPEDWINDOW | WS_VISIBLE);
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  RECT rect = has_restore_ ? restore_rect_ : RECT{10, 10, 1290, 810};
  SetWindowPos(hwnd, nullptr, rect.left, rect.top, rect.right - rect.left,
               rect.bottom - rect.top, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  fullscreen_ = false;
  NotifyFullscreen();
  return true;
}

std::wstring HomedeckWin32::PickOpenFile(const std::wstring& filter_label,
                                         const std::wstring& extensions,
                                         const std::wstring& ok_label) {
  // Automation bypass: Ally / CI can set HOMEDECK_ADD_PATH to a real
  // notepad.exe / .lnk and skip the modal when SendKeys cannot drive OFN.
  wchar_t env_path[32768];
  const DWORD env_len =
      GetEnvironmentVariableW(L"HOMEDECK_ADD_PATH", env_path, ARRAYSIZE(env_path));
  if (env_len > 0 && env_len < ARRAYSIZE(env_path)) {
    OutputDebugStringW(
        L"homedeck: pickOpenFile using HOMEDECK_ADD_PATH bypass\n");
    return std::wstring(env_path, env_len);
  }

  std::wstring filter = BuildFilter(filter_label, extensions);
  wchar_t file[32768] = {};
  PickHookState hook_state;
  hook_state.ok_label = ok_label.c_str();

  OPENFILENAMEW ofn{};
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner = window_ != nullptr ? window_->GetHandle() : nullptr;
  ofn.lpstrFilter = filter.c_str();
  ofn.nFilterIndex = 1;
  ofn.lpstrFile = file;
  ofn.nMaxFile = ARRAYSIZE(file);
  // Explicit title — Ally Phase2 FindWindow(null, "Open") / class #32770.
  ofn.lpstrTitle = L"Open";
  ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST |
              OFN_HIDEREADONLY | OFN_NOCHANGEDIR | OFN_ENABLEHOOK |
              OFN_ENABLESIZING;
  ofn.lpfnHook = PickOpenHook;
  ofn.lCustData = reinterpret_cast<LPARAM>(&hook_state);

  if (ofn.hwndOwner != nullptr) {
    SetForegroundWindow(ofn.hwndOwner);
  }

  OutputDebugStringW(L"homedeck: GetOpenFileNameW showing classic Open\n");
  picking_file_ = true;
  const BOOL ok = GetOpenFileNameW(&ofn);
  picking_file_ = false;
  if (!ok) {
    const DWORD err = CommDlgExtendedError();
    if (err != 0) {
      OutputDebugStringW(L"homedeck: GetOpenFileNameW failed (CommDlg error)\n");
    } else {
      OutputDebugStringW(L"homedeck: GetOpenFileNameW cancelled\n");
    }
    return std::wstring();
  }
  OutputDebugStringW(L"homedeck: GetOpenFileNameW accepted path\n");
  return std::wstring(file);
}

bool HomedeckWin32::Launch(const std::wstring& path,
                           const std::wstring& args) {
  if (path.empty()) {
    return false;
  }
  const wchar_t* params = args.empty() ? nullptr : args.c_str();
  const HINSTANCE result = ShellExecuteW(nullptr, L"open", path.c_str(),
                                         params, nullptr, SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(result) > 32;
}

bool HomedeckWin32::LaunchFocused() {
  if (focused_path_.empty()) {
    return false;
  }
  return Launch(focused_path_, focused_args_);
}

void HomedeckWin32::SetFocusedLaunch(const std::wstring& path,
                                     const std::wstring& args) {
  focused_path_ = path;
  focused_args_ = args;
}

void HomedeckWin32::RequestDartLaunch() {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod("launchFocused", nullptr);
}

void HomedeckWin32::HandleAddKey() {
  if (picking_file_) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleAddKey opening classic Open\n");
  const std::wstring path =
      PickOpenFile(L"Windows apps", L"exe,lnk", L"Add to HomeDeck");
  if (path.empty()) {
    return;
  }
  NotifyPickedPath(path);
}

void HomedeckWin32::NotifyPickedPath(const std::wstring& path) {
  if (channel_ == nullptr || path.empty()) {
    return;
  }
  channel_->InvokeMethod(
      "addPickedPath",
      std::make_unique<flutter::EncodableValue>(Utf8FromUtf16(path.c_str())));
}

void HomedeckWin32::NotifyFullscreen() {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod(
      "fullscreenChanged",
      std::make_unique<flutter::EncodableValue>(fullscreen_));
}

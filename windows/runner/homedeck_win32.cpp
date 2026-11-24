#include "homedeck_win32.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

namespace {

constexpr char kChannel[] = "homedeck/win32";

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

}  // namespace

void HomedeckWin32::Register(flutter::BinaryMessenger* messenger,
                             Win32Window* window) {
  window_ = window;
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
        if (method == "isFullscreen") {
          result->Success(flutter::EncodableValue(fullscreen_));
          return;
        }
        result->NotImplemented();
      });
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
    SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowPos(hwnd, HWND_TOP, target.left, target.top,
                 target.right - target.left, target.bottom - target.top,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
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

void HomedeckWin32::NotifyFullscreen() {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod(
      "fullscreenChanged",
      std::make_unique<flutter::EncodableValue>(fullscreen_));
}

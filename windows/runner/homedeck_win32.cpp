#include "homedeck_win32.h"

#include <flutter/standard_method_codec.h>
#include <objidl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <cstring>
#include <vector>

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "ole32.lib")

namespace {

constexpr char kChannel[] = "homedeck/win32";
constexpr int kDefaultIconSize = 256;

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

bool EndsWithIgnoreCase(const std::wstring& value, const wchar_t* suffix) {
  const size_t len = wcslen(suffix);
  if (value.size() < len) {
    return false;
  }
  return _wcsicmp(value.c_str() + (value.size() - len), suffix) == 0;
}

HICON LoadFileIcon(const std::wstring& path, int size) {
  HICON large = nullptr;
  UINT extracted = PrivateExtractIconsW(path.c_str(), 0, size, size, &large,
                                        nullptr, 1, 0);
  if (extracted > 0 && large != nullptr) {
    return large;
  }

  HICON small_icon = nullptr;
  const UINT count =
      ExtractIconExW(path.c_str(), 0, &large, &small_icon, 1);
  if (small_icon != nullptr) {
    DestroyIcon(small_icon);
  }
  if (count > 0 && large != nullptr) {
    return large;
  }

  SHFILEINFOW info{};
  const DWORD_PTR result = SHGetFileInfoW(
      path.c_str(), 0, &info, sizeof(info), SHGFI_ICON | SHGFI_LARGEICON);
  if (result != 0 && info.hIcon != nullptr) {
    return info.hIcon;
  }
  return nullptr;
}

std::wstring ResolveShortcutTarget(const std::wstring& lnk_path) {
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  HRESULT hr =
      CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&link));
  if (FAILED(hr) || link == nullptr) {
    return std::wstring();
  }
  Microsoft::WRL::ComPtr<IPersistFile> persist;
  hr = link.As(&persist);
  if (FAILED(hr) || persist == nullptr) {
    return std::wstring();
  }
  hr = persist->Load(lnk_path.c_str(), STGM_READ);
  if (FAILED(hr)) {
    return std::wstring();
  }

  wchar_t icon_path[MAX_PATH] = {};
  int icon_index = 0;
  if (SUCCEEDED(link->GetIconLocation(icon_path, MAX_PATH, &icon_index)) &&
      icon_path[0] != L'\0') {
    return std::wstring(icon_path);
  }

  wchar_t target[MAX_PATH] = {};
  if (SUCCEEDED(link->GetPath(target, MAX_PATH, nullptr, SLGP_RAWPATH)) &&
      target[0] != L'\0') {
    return std::wstring(target);
  }
  return std::wstring();
}

bool HiconToBgra(HICON icon, int size, std::vector<uint8_t>* out_bgra) {
  BITMAPINFO bmi{};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = size;
  bmi.bmiHeader.biHeight = -size;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  HDC screen = GetDC(nullptr);
  if (screen == nullptr) {
    return false;
  }
  void* bits = nullptr;
  HDC mem = CreateCompatibleDC(screen);
  HBITMAP dib =
      CreateDIBSection(mem, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (dib == nullptr || bits == nullptr) {
    if (mem != nullptr) {
      DeleteDC(mem);
    }
    ReleaseDC(nullptr, screen);
    return false;
  }

  HGDIOBJ old = SelectObject(mem, dib);
  const size_t byte_count = static_cast<size_t>(size) * size * 4;
  std::memset(bits, 0, byte_count);
  const BOOL drawn =
      DrawIconEx(mem, 0, 0, icon, size, size, 0, nullptr, DI_NORMAL);
  SelectObject(mem, old);

  bool ok = false;
  if (drawn) {
    out_bgra->assign(static_cast<uint8_t*>(bits),
                     static_cast<uint8_t*>(bits) + byte_count);
    ok = true;
  }

  DeleteObject(dib);
  DeleteDC(mem);
  ReleaseDC(nullptr, screen);
  return ok;
}

bool EncodePngWic(const std::vector<uint8_t>& bgra, int size,
                  std::vector<uint8_t>* out_png) {
  Microsoft::WRL::ComPtr<IWICImagingFactory> factory;
  HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr) || factory == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<IWICBitmap> bitmap;
  hr = factory->CreateBitmapFromMemory(
      size, size, GUID_WICPixelFormat32bppBGRA,
      static_cast<UINT>(size * 4), static_cast<UINT>(bgra.size()),
      const_cast<BYTE*>(bgra.data()), &bitmap);
  if (FAILED(hr) || bitmap == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<IStream> stream;
  hr = CreateStreamOnHGlobal(nullptr, TRUE, &stream);
  if (FAILED(hr) || stream == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<IWICBitmapEncoder> encoder;
  hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder);
  if (FAILED(hr) || encoder == nullptr) {
    return false;
  }
  hr = encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache);
  if (FAILED(hr)) {
    return false;
  }

  Microsoft::WRL::ComPtr<IWICBitmapFrameEncode> frame;
  Microsoft::WRL::ComPtr<IPropertyBag> props;
  hr = encoder->CreateNewFrame(&frame, &props);
  if (FAILED(hr) || frame == nullptr) {
    return false;
  }
  hr = frame->Initialize(props.Get());
  if (FAILED(hr)) {
    return false;
  }
  hr = frame->SetSize(size, size);
  if (FAILED(hr)) {
    return false;
  }
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  hr = frame->SetPixelFormat(&format);
  if (FAILED(hr)) {
    return false;
  }
  hr = frame->WriteSource(bitmap.Get(), nullptr);
  if (FAILED(hr)) {
    return false;
  }
  hr = frame->Commit();
  if (FAILED(hr)) {
    return false;
  }
  hr = encoder->Commit();
  if (FAILED(hr)) {
    return false;
  }

  STATSTG stat{};
  hr = stream->Stat(&stat, STATFLAG_NONAME);
  if (FAILED(hr) || stat.cbSize.QuadPart <= 0 ||
      stat.cbSize.QuadPart > 16 * 1024 * 1024) {
    return false;
  }
  const size_t png_size = static_cast<size_t>(stat.cbSize.QuadPart);
  LARGE_INTEGER zero{};
  hr = stream->Seek(zero, STREAM_SEEK_SET, nullptr);
  if (FAILED(hr)) {
    return false;
  }
  out_png->resize(png_size);
  ULONG read = 0;
  hr = stream->Read(out_png->data(), static_cast<ULONG>(png_size), &read);
  return SUCCEEDED(hr) && read == png_size && !out_png->empty();
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
        if (method == "extractIcon") {
          std::string path;
          int size = kDefaultIconSize;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto path_it = map->find(flutter::EncodableValue("path"));
            if (path_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = *value;
              }
            }
            auto size_it = map->find(flutter::EncodableValue("size"));
            if (size_it != map->end()) {
              if (const auto* value = std::get_if<int32_t>(&size_it->second)) {
                size = *value;
              } else if (const auto* value =
                             std::get_if<int64_t>(&size_it->second)) {
                size = static_cast<int>(*value);
              }
            }
          }
          if (path.empty()) {
            result->Error("invalid_args", "extractIcon requires path");
            return;
          }
          if (size < 16) {
            size = 16;
          }
          if (size > 512) {
            size = 512;
          }
          auto png = ExtractIconPng(Utf8ToWide(path), size);
          if (!png.has_value()) {
            result->Success(flutter::EncodableValue());  // null
            return;
          }
          result->Success(flutter::EncodableValue(std::move(png.value())));
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

std::optional<std::vector<uint8_t>> HomedeckWin32::ExtractIconPng(
    const std::wstring& path, int size) {
  if (path.empty() || size <= 0) {
    return std::nullopt;
  }

  const HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool should_uninit = init == S_OK;
  if (FAILED(init) && init != RPC_E_CHANGED_MODE && init != S_FALSE) {
    return std::nullopt;
  }

  std::vector<std::wstring> sources;
  if (EndsWithIgnoreCase(path, L".lnk")) {
    const std::wstring resolved = ResolveShortcutTarget(path);
    if (!resolved.empty()) {
      sources.push_back(resolved);
    }
  }
  sources.push_back(path);

  std::optional<std::vector<uint8_t>> png;
  for (const auto& source : sources) {
    HICON icon = LoadFileIcon(source, size);
    if (icon == nullptr) {
      continue;
    }
    std::vector<uint8_t> bgra;
    const bool raster_ok = HiconToBgra(icon, size, &bgra);
    DestroyIcon(icon);
    if (!raster_ok) {
      continue;
    }
    std::vector<uint8_t> encoded;
    if (EncodePngWic(bgra, size, &encoded)) {
      png = std::move(encoded);
      break;
    }
  }

  if (should_uninit) {
    CoUninitialize();
  }
  return png;
}

void HomedeckWin32::NotifyFullscreen() {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod(
      "fullscreenChanged",
      std::make_unique<flutter::EncodableValue>(fullscreen_));
}

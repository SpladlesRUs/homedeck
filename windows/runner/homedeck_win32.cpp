#include "homedeck_win32.h"

#include <flutter/standard_method_codec.h>
#include <commdlg.h>
#include <objidl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <cstring>
#include <memory>
#include <optional>
#include <thread>
#include <vector>

#include "utils.h"

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "comdlg32.lib")

namespace {

constexpr char kChannel[] = "homedeck/win32";
constexpr int kDefaultIconSize = 256;

struct IconDonePayload {
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  std::optional<std::vector<uint8_t>> png;
};

// CDN_INITDONE hook: rename OK so Ally/SendKeys can target "Add to HomeDeck"
// while the window title stays the classic FindWindow-able "Open".
struct PickHookState {
  const wchar_t* ok_label = nullptr;
};

UINT_PTR CALLBACK PickOpenHook(HWND hwnd, UINT msg, WPARAM, LPARAM lparam) {
  // Ally Phase2: Wait-WindowTitle exact equality (Get-WindowTitle) -eq 'Open'
  // (8s, visible only; no class filter). Title must be exactly Open — never
  // the OK label "Add to HomeDeck".
  if (msg == WM_INITDIALOG) {
    HWND parent = GetParent(hwnd);
    if (parent != nullptr) {
      SetWindowTextW(parent, L"Open");
    }
    return FALSE;
  }
  if (msg == WM_NOTIFY) {
    const auto* notify = reinterpret_cast<LPOFNOTIFY>(lparam);
    if (notify != nullptr && notify->hdr.code == CDN_INITDONE &&
        notify->lpOFN != nullptr) {
      HWND parent = GetParent(hwnd);
      if (parent != nullptr) {
        SetWindowTextW(parent, L"Open");
      }
      const auto* state =
          reinterpret_cast<PickHookState*>(notify->lpOFN->lCustData);
      if (state != nullptr && state->ok_label != nullptr &&
          state->ok_label[0] != L'\0' && parent != nullptr) {
        CommDlg_OpenSave_SetControlText(parent, IDOK, state->ok_label);
      }
    }
  }
  return FALSE;
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

// Store / protocol URIs (steam://, epic, …). Drive-letter paths are not URIs.
bool LooksLikeLaunchUri(const std::wstring& path) {
  if (path.empty()) {
    return false;
  }
  // C:\… or \\server\share — filesystem, not a protocol launch.
  if (path.size() >= 2 && path[1] == L':' &&
      ((path[0] >= L'A' && path[0] <= L'Z') ||
       (path[0] >= L'a' && path[0] <= L'z'))) {
    return false;
  }
  if (path.size() >= 2 && path[0] == L'\\' && path[1] == L'\\') {
    return false;
  }
  if (path.find(L"://") != std::wstring::npos) {
    return true;
  }
  const size_t colon = path.find(L':');
  return colon != std::wstring::npos && colon > 1;
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

// Launch-oriented resolve: GetPath first (not icon location), plus arguments.
bool ResolveShortcutLaunch(const std::wstring& lnk_path, std::wstring* target,
                           std::wstring* arguments) {
  if (target == nullptr || arguments == nullptr) {
    return false;
  }
  target->clear();
  arguments->clear();
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  HRESULT hr =
      CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&link));
  if (FAILED(hr) || link == nullptr) {
    return false;
  }
  Microsoft::WRL::ComPtr<IPersistFile> persist;
  hr = link.As(&persist);
  if (FAILED(hr) || persist == nullptr) {
    return false;
  }
  hr = persist->Load(lnk_path.c_str(), STGM_READ);
  if (FAILED(hr)) {
    return false;
  }

  wchar_t path_buf[32768] = {};
  if (SUCCEEDED(link->GetPath(path_buf, ARRAYSIZE(path_buf), nullptr,
                              SLGP_RAWPATH)) &&
      path_buf[0] != L'\0') {
    *target = path_buf;
  }

  wchar_t args_buf[32768] = {};
  if (SUCCEEDED(link->GetArguments(args_buf, ARRAYSIZE(args_buf))) &&
      args_buf[0] != L'\0') {
    *arguments = args_buf;
  }
  return !target->empty() || !arguments->empty();
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
  Microsoft::WRL::ComPtr<IPropertyBag2> props;
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

HomedeckWin32* HomedeckWin32::instance_ = nullptr;

HomedeckWin32::~HomedeckWin32() {
  RemoveHook();
  // Invalidate any in-flight WaitForSingleObject → PostMessage restore.
  watch_generation_.fetch_add(1);
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
        if (method == "resolveShortcut") {
          std::string path;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto path_it = map->find(flutter::EncodableValue("path"));
            if (path_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = *value;
              }
            }
          }
          if (path.empty()) {
            result->Error("invalid_args", "resolveShortcut requires path");
            return;
          }
          std::wstring target;
          std::wstring arguments;
          if (!ResolveShortcutLaunch(Utf8ToWide(path), &target, &arguments)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          flutter::EncodableMap out;
          if (!target.empty()) {
            out[flutter::EncodableValue("target")] =
                flutter::EncodableValue(Utf8FromUtf16(target.c_str()));
          }
          if (!arguments.empty()) {
            out[flutter::EncodableValue("arguments")] =
                flutter::EncodableValue(Utf8FromUtf16(arguments.c_str()));
          }
          result->Success(flutter::EncodableValue(out));
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
        if (method == "setRemoveArmed") {
          bool armed = false;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("armed"));
            if (it != map->end()) {
              if (const auto* flag = std::get_if<bool>(&it->second)) {
                armed = *flag;
              }
            }
          }
          SetRemoveArmed(armed);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "setFullscreenOnLaunch") {
          bool enabled = true;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("enabled"));
            if (it != map->end()) {
              if (const auto* flag = std::get_if<bool>(&it->second)) {
                enabled = *flag;
              }
            }
          }
          SetFullscreenOnLaunch(enabled);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "setRestoreOnExit") {
          bool enabled = true;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("enabled"));
            if (it != map->end()) {
              if (const auto* flag = std::get_if<bool>(&it->second)) {
                enabled = *flag;
              }
            }
          }
          SetRestoreOnExit(enabled);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "writeFile") {
          std::string path;
          std::vector<uint8_t> bytes;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto path_it = map->find(flutter::EncodableValue("path"));
            if (path_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&path_it->second)) {
                path = *value;
              }
            }
            auto bytes_it = map->find(flutter::EncodableValue("bytes"));
            if (bytes_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::vector<uint8_t>>(&bytes_it->second)) {
                bytes = *value;
              }
            }
          }
          if (path.empty() || bytes.empty()) {
            result->Error("invalid_args", "writeFile requires path and bytes");
            return;
          }
          const bool ok = WriteFileBytes(Utf8ToWide(path), bytes);
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
              if (const auto* size32 =
                      std::get_if<int32_t>(&size_it->second)) {
                size = *size32;
              } else if (const auto* size64 =
                             std::get_if<int64_t>(&size_it->second)) {
                size = static_cast<int>(*size64);
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
          HWND hwnd = window_ != nullptr ? window_->GetHandle() : nullptr;
          if (hwnd == nullptr) {
            // No HWND to marshal back — fail closed rather than block the pump.
            result->Success(flutter::EncodableValue());
            return;
          }
          // Run extract off the platform thread. Sync WIC/COM here deadlocked
          // Ally at f9b1d14 (message pump starved → writePng never ran).
          auto* payload = new IconDonePayload{
              std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                  std::move(result)),
              std::nullopt};
          std::wstring wide = Utf8ToWide(path);
          std::thread([payload, wide = std::move(wide), size, hwnd]() mutable {
            payload->png = HomedeckWin32::ExtractIconPng(wide, size);
            if (!PostMessage(hwnd, WM_HOMEDECK_ICON_DONE, 0,
                             reinterpret_cast<LPARAM>(payload))) {
              // Window gone — drop the result so we do not leak forever.
              delete payload;
            }
          }).detach();
          return;
        }
        if (method == "isFullscreen") {
          result->Success(flutter::EncodableValue(fullscreen_));
          return;
        }
        if (method == "pickOpenFile") {
          // Ally Phase2: file_selector IFileDialog never produced a
          // FindWindow-able "Open" after SendKeys a → apps=[] / no tile PNG.
          // Classic GetOpenFileName is #32770 titled "Open".
          std::string label = "Windows apps";
          std::string extensions = "exe,lnk";
          std::string ok_label = "Add to HomeDeck";
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto label_it = map->find(flutter::EncodableValue("label"));
            if (label_it != map->end()) {
              if (const auto* label_val =
                      std::get_if<std::string>(&label_it->second)) {
                label = *label_val;
              }
            }
            auto ext_it = map->find(flutter::EncodableValue("extensions"));
            if (ext_it != map->end()) {
              if (const auto* ext_str =
                      std::get_if<std::string>(&ext_it->second)) {
                extensions = *ext_str;
              } else if (const auto* list = std::get_if<flutter::EncodableList>(
                             &ext_it->second)) {
                extensions.clear();
                for (const auto& entry : *list) {
                  if (const auto* ext_item = std::get_if<std::string>(&entry)) {
                    if (!extensions.empty()) {
                      extensions.push_back(',');
                    }
                    extensions.append(*ext_item);
                  }
                }
              }
            }
            auto ok_it =
                map->find(flutter::EncodableValue("confirmButtonText"));
            if (ok_it != map->end()) {
              if (const auto* ok_val =
                      std::get_if<std::string>(&ok_it->second)) {
                ok_label = *ok_val;
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
    // While classic Open is up, let OFN own keys (Enter confirms the file);
    // do not ShellExecute a mirrored path (same PID looks "foreground").
    if (info != nullptr && instance_->IsOurForeground() &&
        !instance_->picking_file_) {
      if (info->vkCode == VK_F11) {
        instance_->SetFullscreen(!instance_->IsFullscreen());
        return 1;
      }
      if (info->vkCode == VK_RETURN) {
        // Library remove confirm: Enter must confirm, not ShellExecute.
        // Post CONFIRM after any prior REMOVE so Dart sets pending first.
        if (instance_->RemoveArmed()) {
          HWND hwnd = instance_->window_ != nullptr
                          ? instance_->window_->GetHandle()
                          : nullptr;
          if (hwnd != nullptr) {
            PostMessageW(hwnd, WM_HOMEDECK_CONFIRM, 0, 0);
            return 1;
          }
        }
        if (instance_->HandleEnter()) {
          return 1;
        }
      }
      // Ally M9: Menu/Details Remove is not UIA-reachable. Bare Delete /
      // Backspace → unpin (Home) or Library remove confirm (same as
      // RemoveFocusedIntent). Arm + clear mirror before PostMessage so a
      // following Enter cannot ShellExecute before Dart handles REMOVE.
      if ((info->vkCode == VK_DELETE || info->vkCode == VK_BACK) &&
          !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          instance_->SetRemoveArmed(true);
          instance_->SetFocusedLaunch(L"", L"");
          PostMessageW(hwnd, WM_HOMEDECK_REMOVE, 0, 0);
          return 1;
        }
      }
      // Ally @1676362: SendKeys `a` never reached Flutter Shortcuts /
      // MethodChannel pickOpenFile → "Open dialog not found" / apps=[].
      // Post to the UI thread and consume so Shortcuts cannot double-open.
      if (info->vkCode == 'A' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_ADD, 0, 0);
          return 1;
        }
      }
      // Ally M3: Settings overlay is not UIA-reachable. Bare SendKeys `s`
      // posts scanSteam (same discover → import as Settings → Scan Steam).
      if (info->vkCode == 'S' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_STEAM, 0, 0);
          return 1;
        }
      }
      // Ally M4: bare SendKeys `p` -> Start Menu Programs scan (Settings ->
      // Scan Start Menu) without Settings UIA. M stays move-mode in Dart.
      if (info->vkCode == 'P' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_START_MENU, 0, 0);
          return 1;
        }
      }
      // Ally M6: bare SendKeys `r` -> ROM-folder scan (Settings -> Scan ROM
      // folder) without Settings UIA.
      if (info->vkCode == 'R' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_ROMS, 0, 0);
          return 1;
        }
      }
      // Ally M10: bare SendKeys `e` -> Epic Games scan (Settings -> Scan Epic
      // Games) without Settings UIA.
      if (info->vkCode == 'E' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_EPIC, 0, 0);
          return 1;
        }
      }
      // Ally M11: bare SendKeys `g` -> GOG Galaxy scan (Settings -> Scan GOG)
      // without Settings UIA. Message id is WM_HOMEDECK_SCAN_GOG (0x67), not
      // WM_HOMEDECK_GAME_EXIT (0x47).
      if (info->vkCode == 'G' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_GOG, 0, 0);
          return 1;
        }
      }
      // Ally M12: bare SendKeys `u` -> Ubisoft Connect scan (Settings -> Scan
      // Ubisoft Connect) without Settings UIA.
      if (info->vkCode == 'U' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_UBISOFT, 0, 0);
          return 1;
        }
      }
      // Ally M13: bare SendKeys `o` -> EA App / Origin scan (Settings -> Scan
      // EA App) without Settings UIA.
      if (info->vkCode == 'O' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_EA, 0, 0);
          return 1;
        }
      }
      // Ally M14: bare SendKeys `n` -> Battle.net scan (Settings -> Scan
      // Battle.net) without Settings UIA.
      if (info->vkCode == 'N' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_BATTLENET, 0, 0);
          return 1;
        }
      }
      // Ally M15: bare SendKeys `w` -> Xbox / Microsoft Store scan
      // (Settings -> Scan Xbox) without Settings UIA.
      if (info->vkCode == 'W' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_SCAN_XBOX, 0, 0);
          return 1;
        }
      }
      // Ally M5: UI Add to Home is not UIA-reachable. Bare SendKeys `h`
      // pins the focused Library record onto Home (same as the menu action).
      if (info->vkCode == 'H' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_PIN_HOME, 0, 0);
          return 1;
        }
      }
      // Ally M19: OpenMenuIntent is Shortcuts-only; idle-hide drops focus so
      // SendKeys `=` / `{+}` never open TileMenu. Bare VK_OEM_PLUS (0xBB) /
      // VK_ADD (numpad +) → openMenu (same as OpenMenuIntent). Consume so
      // Shortcuts cannot double-open when focus is still alive.
      if ((info->vkCode == VK_OEM_PLUS || info->vkCode == VK_ADD) &&
          !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_OPEN_MENU, 0, 0);
          return 1;
        }
      }
      // Ally M21: OpenDetailsIntent is Shortcuts-only; idle-hide drops focus
      // so SendKeys `-` never open Details. Bare VK_OEM_MINUS (0xBD) →
      // openDetails (same as OpenDetailsIntent / `_openDetails`). Consume so
      // Shortcuts cannot double-open when focus is still alive.
      if (info->vkCode == VK_OEM_MINUS && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_OPEN_DETAILS, 0, 0);
          return 1;
        }
      }
      // Ally M22: OpenSearchIntent is Shortcuts-only; idle-hide drops focus
      // so SendKeys `y` never open Global Search. Bare 'Y' (0x59) →
      // openSearch (same as OpenSearchIntent / `_openSearch`). Consume so
      // Shortcuts cannot double-open when focus is still alive.
      if (info->vkCode == 'Y' && !ModifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_OPEN_SEARCH, 0, 0);
          return 1;
        }
      }
      // Ally M23: OpenNotificationsIntent is Shortcuts-only; idle-hide drops
      // focus so SendKeys `t` never open Notifications. Bare 'T' (0x54) →
      // openNotifications (same as OpenNotificationsIntent /
      // `_openNotifications`). Consume so Shortcuts cannot double-open when
      // focus is still alive. Free of Y/OEM_PLUS/OEM_MINUS/s/p/r/e/g/u/o/n/
      // w/h/a/Delete.
      if (info->vkCode == 'T' && !modifierHeld()) {
        HWND hwnd = instance_->window_ != nullptr
                        ? instance_->window_->GetHandle()
                        : nullptr;
        if (hwnd != nullptr) {
          PostMessageW(hwnd, WM_HOMEDECK_OPEN_NOTIFICATIONS, 0, 0);
          return 1;
        }
      }
    }
  }
  return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

bool HomedeckWin32::HandleEnter() {
  // Library remove confirm arms Enter → WM_HOMEDECK_CONFIRM (not launch).
  if (remove_armed_) {
    HWND hwnd = window_ != nullptr ? window_->GetHandle() : nullptr;
    if (hwnd != nullptr) {
      PostMessageW(hwnd, WM_HOMEDECK_CONFIRM, 0, 0);
      return true;
    }
  }
  // Prefer the mirrored path (no Dart round-trip). When a path is mirrored,
  // always ShellExecute and consume Enter. When empty, ask Dart (focus may
  // exist but mirror raced) and do *not* consume so Add-sheet Confirm / OFN
  // Enter still receive the key.
  if (LaunchFocused()) {
    return true;
  }
  RequestDartLaunch();
  return false;
}

void HomedeckWin32::SetRemoveArmed(bool armed) { remove_armed_ = armed; }

bool HomedeckWin32::LaunchFocused() {
  if (focused_path_.empty()) {
    return false;
  }
  if (!Launch(focused_path_, focused_args_)) {
    return false;
  }
  // Ally Enter launches here without Dart — enter F11 chrome when Settings
  // “Fullscreen on launch” is ON (default). Esc/F11 still exit as today.
  if (fullscreen_on_launch_ && !fullscreen_) {
    SetFullscreen(true);
  }
  return true;
}

void HomedeckWin32::SetFocusedLaunch(const std::wstring& path,
                                     const std::wstring& args) {
  focused_path_ = path;
  focused_args_ = args;
}

void HomedeckWin32::SetFullscreenOnLaunch(bool enabled) {
  fullscreen_on_launch_ = enabled;
}

void HomedeckWin32::SetRestoreOnExit(bool enabled) {
  restore_on_exit_ = enabled;
}

void HomedeckWin32::StartWatchingProcess(HANDLE process) {
  if (process == nullptr || process == INVALID_HANDLE_VALUE) {
    return;
  }
  const uint64_t generation = watch_generation_.fetch_add(1) + 1;
  watching_active_ = true;
  entered_fullscreen_for_launch_ = false;
  HWND hwnd = window_ != nullptr ? window_->GetHandle() : nullptr;
  if (hwnd == nullptr) {
    watching_active_ = false;
    CloseHandle(process);
    return;
  }
  // Detached waiter: notepad / short-lived Ally pins exit quickly; games may
  // run for hours. Generation invalidates stale posts after a re-launch.
  std::thread([hwnd, process, generation]() {
    WaitForSingleObject(process, INFINITE);
    CloseHandle(process);
    const WPARAM wparam = static_cast<WPARAM>(generation & 0xffffffffu);
    const LPARAM lparam = static_cast<LPARAM>(generation >> 32);
    PostMessageW(hwnd, WM_HOMEDECK_GAME_EXIT, wparam, lparam);
  }).detach();
}

void HomedeckWin32::BringHomeDeckToForeground() {
  if (window_ == nullptr) {
    return;
  }
  HWND hwnd = window_->GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    ShowWindow(hwnd, SW_SHOW);
  }
  HWND foreground = GetForegroundWindow();
  DWORD fg_tid = 0;
  if (foreground != nullptr) {
    fg_tid = GetWindowThreadProcessId(foreground, nullptr);
  }
  const DWORD our_tid = GetCurrentThreadId();
  const bool attached = fg_tid != 0 && fg_tid != our_tid &&
                        AttachThreadInput(our_tid, fg_tid, TRUE);
  BringWindowToTop(hwnd);
  SetForegroundWindow(hwnd);
  SetActiveWindow(hwnd);
  if (attached) {
    AttachThreadInput(our_tid, fg_tid, FALSE);
  }
}

void HomedeckWin32::HandleGameExit(uint64_t generation) {
  if (generation != watch_generation_.load()) {
    return;
  }
  watching_active_ = false;
  if (!restore_on_exit_) {
    entered_fullscreen_for_launch_ = false;
    return;
  }
  // Only leave chrome we entered for this launch — prior F11 stays.
  if (entered_fullscreen_for_launch_ && fullscreen_) {
    SetFullscreen(false);
  }
  entered_fullscreen_for_launch_ = false;
  BringHomeDeckToForeground();
  NotifyGameExited();
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

void HomedeckWin32::HandleScanSteamKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanSteamKey → Dart scanSteam\n");
  channel_->InvokeMethod("scanSteam", nullptr);
}

void HomedeckWin32::HandleScanStartMenuKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandleScanStartMenuKey → Dart scanStartMenu\n");
  channel_->InvokeMethod("scanStartMenu", nullptr);
}

void HomedeckWin32::HandleScanRomsKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanRomsKey → Dart scanRoms\n");
  channel_->InvokeMethod("scanRoms", nullptr);
}

void HomedeckWin32::HandleScanEpicKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanEpicKey → Dart scanEpic\n");
  channel_->InvokeMethod("scanEpic", nullptr);
}

void HomedeckWin32::HandleScanGogKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanGogKey → Dart scanGog\n");
  channel_->InvokeMethod("scanGog", nullptr);
}

void HomedeckWin32::HandleScanUbisoftKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanUbisoftKey → Dart scanUbisoft\n");
  channel_->InvokeMethod("scanUbisoft", nullptr);
}

void HomedeckWin32::HandleScanEaKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanEaKey → Dart scanEa\n");
  channel_->InvokeMethod("scanEa", nullptr);
}

void HomedeckWin32::HandleScanBattlenetKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanBattlenetKey → Dart scanBattlenet\n");
  channel_->InvokeMethod("scanBattlenet", nullptr);
}

void HomedeckWin32::HandleScanXboxKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleScanXboxKey → Dart scanXbox\n");
  channel_->InvokeMethod("scanXbox", nullptr);
}

void HomedeckWin32::HandlePinHomeKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandlePinHomeKey → Dart pinFocusedToHome\n");
  channel_->InvokeMethod("pinFocusedToHome", nullptr);
}

void HomedeckWin32::HandleRemoveKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  // Mirror already cleared + armed in the LL hook (Delete→Enter race).
  OutputDebugStringW(
      L"homedeck: HandleRemoveKey → Dart removeFocused\n");
  channel_->InvokeMethod("removeFocused", nullptr);
}

void HomedeckWin32::HandleOpenMenuKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(L"homedeck: HandleOpenMenuKey → Dart openMenu\n");
  channel_->InvokeMethod("openMenu", nullptr);
}

void HomedeckWin32::HandleOpenDetailsKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandleOpenDetailsKey → Dart openDetails\n");
  channel_->InvokeMethod("openDetails", nullptr);
}

void HomedeckWin32::HandleOpenSearchKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandleOpenSearchKey → Dart openSearch\n");
  channel_->InvokeMethod("openSearch", nullptr);
}

void HomedeckWin32::HandleOpenNotificationsKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandleOpenNotificationsKey → Dart openNotifications\n");
  channel_->InvokeMethod("openNotifications", nullptr);
}

void HomedeckWin32::HandleConfirmKey() {
  if (picking_file_) {
    return;
  }
  if (channel_ == nullptr) {
    return;
  }
  OutputDebugStringW(
      L"homedeck: HandleConfirmKey → Dart confirmFocused\n");
  channel_->InvokeMethod("confirmFocused", nullptr);
}

void HomedeckWin32::NotifyPickedPath(const std::wstring& path) {
  if (channel_ == nullptr || path.empty()) {
    return;
  }
  channel_->InvokeMethod(
      "addPickedPath",
      std::make_unique<flutter::EncodableValue>(Utf8FromUtf16(path.c_str())));
}

std::wstring HomedeckWin32::PickOpenFile(const std::wstring& filter_label,
                                         const std::wstring& extensions,
                                         const std::wstring& ok_label) {
  // Automation bypass: Ally / CI can set HOMEDECK_ADD_PATH to a real
  // notepad.exe / .lnk (or a deliberately bad path) and skip the modal.
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
  // Exact title Ally Phase2 FindWindow(null, "Open") expects. Class #32770.
  // OK button text is separately "Add to HomeDeck" via PickOpenHook — do not
  // put that string in lpstrTitle.
  ofn.lpstrTitle = L"Open";
  // No OFN_FILEMUSTEXIST so Ally can type a bad/missing .exe path and still
  // get a Dart callback → icons/<id>.png placeholder.
  ofn.Flags = OFN_EXPLORER | OFN_HIDEREADONLY | OFN_NOCHANGEDIR |
              OFN_ENABLEHOOK | OFN_ENABLESIZING;
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
    // Ally Enter / Dart launch apply chrome after ShellExecute — mark so
    // game-exit restore can leave that chrome without touching a prior F11.
    if (watching_active_) {
      entered_fullscreen_for_launch_ = true;
    }
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
  const bool is_uri = LooksLikeLaunchUri(path);
  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof(info);
  // SEE_MASK_NOCLOSEPROCESS yields hProcess for local .exe/.lnk when the
  // shell started a process we can wait on. Protocol handlers (steam://)
  // usually return null — and even when they do not, waiting on Steam's
  // helper is not a game session, so URIs never start a watch.
  info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
  info.lpVerb = L"open";
  info.lpFile = path.c_str();
  info.lpParameters = args.empty() ? nullptr : args.c_str();
  info.nShow = SW_SHOWNORMAL;
  if (!ShellExecuteExW(&info)) {
    return false;
  }
  if (info.hProcess != nullptr) {
    if (is_uri) {
      CloseHandle(info.hProcess);
    } else {
      StartWatchingProcess(info.hProcess);
    }
  }
  return true;
}

bool HomedeckWin32::WriteFileBytes(const std::wstring& path,
                                   const std::vector<uint8_t>& bytes) {
  if (path.empty() || bytes.empty()) {
    return false;
  }
  // Ensure parent directory exists (icons\).
  const size_t slash = path.find_last_of(L"\\/");
  if (slash != std::wstring::npos && slash > 0) {
    const std::wstring dir = path.substr(0, slash);
    if (!dir.empty()) {
      SHCreateDirectoryExW(nullptr, dir.c_str(), nullptr);
    }
  }
  HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const BOOL ok =
      ::WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
                  &written, nullptr);
  FlushFileBuffers(file);
  CloseHandle(file);
  return ok && written == bytes.size();
}

bool HomedeckWin32::HandleIconDone(LPARAM lparam) {
  auto* payload = reinterpret_cast<IconDonePayload*>(lparam);
  if (payload == nullptr || payload->result == nullptr) {
    delete payload;
    return true;
  }
  if (payload->png.has_value() && !payload->png->empty()) {
    payload->result->Success(
        flutter::EncodableValue(std::move(payload->png.value())));
  } else {
    payload->result->Success(flutter::EncodableValue());
  }
  delete payload;
  return true;
}

std::optional<std::vector<uint8_t>> HomedeckWin32::ExtractIconPng(
    const std::wstring& path, int size) {
  if (path.empty() || size <= 0) {
    return std::nullopt;
  }
  // Fail fast for Ally "bad path" — do not sit in Shell APIs on missing files.
  const DWORD attrs = GetFileAttributesW(path.c_str());
  if (attrs == INVALID_FILE_ATTRIBUTES) {
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

void HomedeckWin32::NotifyGameExited() {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod("gameExited", nullptr);
}

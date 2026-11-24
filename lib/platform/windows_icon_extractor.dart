// ignore_for_file: camel_case_types, constant_identifier_names, non_constant_identifier_names, deprecated_member_use

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:homedeck/core/windows_paths.dart';

/// Extracts a PNG tile from a Windows `.exe` or `.lnk` path.
///
/// Injected into [WindowsAdapter] so unit tests can supply canned bytes
/// without loading shell32 / user32.
abstract class WindowsIconExtractor {
  /// Returns PNG bytes, or `null` when extraction is unavailable or fails.
  Future<Uint8List?> extractPng(String path);
}

/// Win32 Shell / GDI extractor: resolve `.lnk` → target, then pull the PE
/// (or Shell-associated) icon and encode it as PNG.
class Win32IconExtractor implements WindowsIconExtractor {
  Win32IconExtractor();

  static const _iconSize = 256;
  static const _maxPath = 260;

  bool _bindFailed = false;
  _Win32IconApis? _apis;

  @override
  Future<Uint8List?> extractPng(String path) async {
    if (!Platform.isWindows) {
      return null;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final apis = _ensureApis();
    if (apis == null) {
      return null;
    }

    try {
      final sources = <String>[];
      if (WindowsPaths.isShortcut(trimmed)) {
        final resolved = _resolveShortcut(apis, trimmed);
        if (resolved != null) {
          if (resolved.iconPath != null && resolved.iconPath!.isNotEmpty) {
            sources.add(resolved.iconPath!);
          }
          if (resolved.targetPath != null && resolved.targetPath!.isNotEmpty) {
            sources.add(resolved.targetPath!);
          }
        }
      }
      sources.add(trimmed);

      for (final source in sources) {
        final hIcon = _loadIcon(apis, source);
        if (hIcon == null || hIcon == 0) {
          continue;
        }
        try {
          final png = await _hiconToPng(apis, hIcon, _iconSize);
          if (png != null && png.isNotEmpty) {
            return png;
          }
        } finally {
          apis.destroyIcon(hIcon);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  _Win32IconApis? _ensureApis() {
    if (_apis != null) {
      return _apis;
    }
    if (_bindFailed) {
      return null;
    }
    try {
      _apis = _Win32IconApis.bind();
      return _apis;
    } catch (_) {
      _bindFailed = true;
      return null;
    }
  }

  _ShortcutPaths? _resolveShortcut(_Win32IconApis apis, String lnkPath) {
    if (apis.coInitializeEx == null ||
        apis.coCreateInstance == null ||
        apis.coUninitialize == null) {
      return null;
    }
    final hrInit = apis.coInitializeEx!(nullptr, _COINIT_APARTMENTTHREADED);
    // Only balance CoUninitialize when this call performed the initialize.
    final shouldUninit = hrInit == _S_OK;
    if (hrInit != _S_OK &&
        hrInit != _S_FALSE &&
        hrInit != _RPC_E_CHANGED_MODE) {
      return null;
    }
    Pointer<Pointer<COMObject>>? ppv;
    Pointer<GUID>? clsid;
    Pointer<GUID>? iidLink;
    Pointer<GUID>? iidPersist;
    Pointer<Utf16>? pathPtr;
    Pointer<Utf16>? targetBuf;
    Pointer<Utf16>? iconBuf;
    Pointer<Int32>? iconIndex;
    try {
      ppv = calloc<Pointer<COMObject>>();
      clsid = _guidFromString(_CLSID_ShellLink);
      iidLink = _guidFromString(_IID_IShellLinkW);
      iidPersist = _guidFromString(_IID_IPersistFile);
      final hrCreate = apis.coCreateInstance!(
        clsid,
        nullptr,
        _CLSCTX_INPROC_SERVER,
        iidLink,
        ppv,
      );
      if (hrCreate != _S_OK || ppv.value == nullptr) {
        return null;
      }
      final link = ppv.value;
      final persist = _queryInterface(link, iidPersist);
      if (persist == null) {
        _release(link);
        return null;
      }
      pathPtr = lnkPath.toNativeUtf16();
      final load = persist.ref.vtable
          .elementAt(5)
          .cast<Pointer<NativeFunction<_LoadNative>>>()
          .value
          .asFunction<_LoadDart>();
      final hrLoad = load(persist, pathPtr, _STGM_READ);
      if (hrLoad != _S_OK) {
        _release(persist);
        _release(link);
        return null;
      }

      targetBuf = calloc<Uint16>(_maxPath + 1).cast<Utf16>();
      iconBuf = calloc<Uint16>(_maxPath + 1).cast<Utf16>();
      iconIndex = calloc<Int32>();

      final getPath = link.ref.vtable
          .elementAt(3)
          .cast<Pointer<NativeFunction<_GetPathNative>>>()
          .value
          .asFunction<_GetPathDart>();
      getPath(link, targetBuf, _maxPath, nullptr, _SLGP_RAWPATH);

      // IShellLinkW vtable: IUnknown (0-2), GetPath (3), … GetIconLocation (16).
      final getIconLocation = link.ref.vtable
          .elementAt(16)
          .cast<Pointer<NativeFunction<_GetIconLocationNative>>>()
          .value
          .asFunction<_GetIconLocationDart>();
      getIconLocation(link, iconBuf, _maxPath, iconIndex);

      final target = targetBuf.toDartString().trim();
      final icon = iconBuf.toDartString().trim();
      _release(persist);
      _release(link);
      return _ShortcutPaths(
        targetPath: target.isEmpty ? null : target,
        iconPath: icon.isEmpty ? null : icon,
      );
    } catch (_) {
      return null;
    } finally {
      if (pathPtr != null) {
        calloc.free(pathPtr);
      }
      if (targetBuf != null) {
        calloc.free(targetBuf);
      }
      if (iconBuf != null) {
        calloc.free(iconBuf);
      }
      if (iconIndex != null) {
        calloc.free(iconIndex);
      }
      if (ppv != null) {
        calloc.free(ppv);
      }
      if (clsid != null) {
        calloc.free(clsid);
      }
      if (iidLink != null) {
        calloc.free(iidLink);
      }
      if (iidPersist != null) {
        calloc.free(iidPersist);
      }
      if (shouldUninit) {
        apis.coUninitialize!();
      }
    }
  }

  int? _loadIcon(_Win32IconApis apis, String path) {
    final pathPtr = path.toNativeUtf16();
    final phicon = calloc<IntPtr>();
    try {
      // Prefer a 256px resource when the PE has one.
      if (apis.privateExtractIcons != null) {
        final count = apis.privateExtractIcons!(
          pathPtr,
          0,
          _iconSize,
          _iconSize,
          phicon,
          nullptr,
          1,
          0,
        );
        if (count > 0 && phicon.value != 0) {
          return phicon.value;
        }
      }

      if (apis.extractIconEx != null) {
        final large = calloc<IntPtr>();
        try {
          final count = apis.extractIconEx!(pathPtr, 0, large, nullptr, 1);
          if (count > 0 && large.value != 0) {
            return large.value;
          }
        } finally {
          calloc.free(large);
        }
      }

      // Shell association covers .lnk display icons and files without PE icons.
      if (apis.shGetFileInfo != null) {
        final info = calloc<SHFILEINFOW>();
        try {
          final result = apis.shGetFileInfo!(
            pathPtr,
            0,
            info,
            sizeOf<SHFILEINFOW>(),
            _SHGFI_ICON | _SHGFI_LARGEICON,
          );
          if (result != 0 && info.ref.hIcon != 0) {
            return info.ref.hIcon;
          }
        } finally {
          calloc.free(info);
        }
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(phicon);
    }
    return null;
  }

  Future<Uint8List?> _hiconToPng(
    _Win32IconApis apis,
    int hIcon,
    int size,
  ) async {
    final hdcScreen = apis.getDC(0);
    if (hdcScreen == 0) {
      return null;
    }
    final hdcMem = apis.createCompatibleDC(hdcScreen);
    Pointer<Uint8>? bitsPtr;
    final bmi = calloc<BITMAPINFO>();
    try {
      bmi.ref.bmiHeader
        ..biSize = sizeOf<BITMAPINFOHEADER>()
        ..biWidth = size
        ..biHeight = -size // top-down
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = _BI_RGB;

      final bitsOut = calloc<Pointer<Uint8>>();
      final dib = apis.createDIBSection(
        hdcMem,
        bmi,
        _DIB_RGB_COLORS,
        bitsOut,
        0, // hSection
        0,
      );
      if (dib == 0 || bitsOut.value == nullptr) {
        calloc.free(bitsOut);
        return null;
      }
      bitsPtr = bitsOut.value;
      calloc.free(bitsOut);

      final old = apis.selectObject(hdcMem, dib);
      // Transparent black; DrawIconEx writes BGRA into the DIB.
      final byteCount = size * size * 4;
      bitsPtr.asTypedList(byteCount).fillRange(0, byteCount, 0);
      final drawn = apis.drawIconEx(
        hdcMem,
        0,
        0,
        hIcon,
        size,
        size,
        0,
        0,
        _DI_NORMAL,
      );
      final rgba = Uint8List(byteCount);
      if (drawn != 0) {
        final bgra = bitsPtr.asTypedList(byteCount);
        for (var i = 0; i < byteCount; i += 4) {
          rgba[i] = bgra[i + 2];
          rgba[i + 1] = bgra[i + 1];
          rgba[i + 2] = bgra[i];
          rgba[i + 3] = bgra[i + 3];
        }
      }
      apis.selectObject(hdcMem, old);
      apis.deleteObject(dib);
      if (drawn == 0) {
        return null;
      }
      return await _encodePng(rgba, size, size);
    } finally {
      apis.deleteDC(hdcMem);
      apis.releaseDC(0, hdcScreen);
      calloc.free(bmi);
    }
  }

  static Future<Uint8List?> _encodePng(
    Uint8List rgba,
    int width,
    int height,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    descriptor.dispose();
    return bytes?.buffer.asUint8List();
  }

  static Pointer<COMObject>? _queryInterface(
    Pointer<COMObject> obj,
    Pointer<GUID> iid,
  ) {
    final out = calloc<Pointer<COMObject>>();
    try {
      final qi = obj.ref.vtable
          .elementAt(0)
          .cast<Pointer<NativeFunction<_QueryInterfaceNative>>>()
          .value
          .asFunction<_QueryInterfaceDart>();
      final hr = qi(obj, iid, out);
      if (hr != _S_OK || out.value == nullptr) {
        return null;
      }
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  static void _release(Pointer<COMObject> obj) {
    final release = obj.ref.vtable
        .elementAt(2)
        .cast<Pointer<NativeFunction<_ReleaseNative>>>()
        .value
        .asFunction<_ReleaseDart>();
    release(obj);
  }

  static Pointer<GUID> _guidFromString(String value) {
    // {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} — Data1/2/3 are numeric groups.
    final hex = value.replaceAll(RegExp('[{}-]'), '');
    final guid = calloc<GUID>();
    guid.ref.Data1 = int.parse(hex.substring(0, 8), radix: 16);
    guid.ref.Data2 = int.parse(hex.substring(8, 12), radix: 16);
    guid.ref.Data3 = int.parse(hex.substring(12, 16), radix: 16);
    for (var i = 0; i < 8; i++) {
      guid.ref.Data4[i] = int.parse(
        hex.substring(16 + i * 2, 18 + i * 2),
        radix: 16,
      );
    }
    return guid;
  }
}

class _ShortcutPaths {
  const _ShortcutPaths({this.targetPath, this.iconPath});

  final String? targetPath;
  final String? iconPath;
}

// --- Win32 constants / structs / bindings ---

const _S_OK = 0;
const _S_FALSE = 1;
const _RPC_E_CHANGED_MODE = 0x80010106;
const _COINIT_APARTMENTTHREADED = 0x2;
const _CLSCTX_INPROC_SERVER = 0x1;
const _STGM_READ = 0;
const _SLGP_RAWPATH = 0x4;
const _SHGFI_ICON = 0x000000100;
const _SHGFI_LARGEICON = 0x000000000;
const _BI_RGB = 0;
const _DIB_RGB_COLORS = 0;
const _DI_NORMAL = 0x0003;

const _CLSID_ShellLink = '{00021401-0000-0000-C000-000000000046}';
const _IID_IShellLinkW = '{000214F9-0000-0000-C000-000000000046}';
const _IID_IPersistFile = '{0000010b-0000-0000-C000-000000000046}';

base class GUID extends Struct {
  @Uint32()
  external int Data1;
  @Uint16()
  external int Data2;
  @Uint16()
  external int Data3;
  @Array(8)
  external Array<Uint8> Data4;
}

base class COMObject extends Struct {
  external Pointer<Pointer<IntPtr>> vtable;
}

base class BITMAPINFOHEADER extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

base class BITMAPINFO extends Struct {
  external BITMAPINFOHEADER bmiHeader;
  @Array(1)
  external Array<Uint32> bmiColors;
}

base class SHFILEINFOW extends Struct {
  @IntPtr()
  external int hIcon;
  @Int32()
  external int iIcon;
  @Uint32()
  external int dwAttributes;
  @Array(260)
  external Array<Uint16> szDisplayName;
  @Array(80)
  external Array<Uint16> szTypeName;
}

typedef _CoInitializeExNative = Int32 Function(Pointer, Uint32);
typedef _CoInitializeExDart = int Function(Pointer, int);
typedef _CoUninitializeNative = Void Function();
typedef _CoUninitializeDart = void Function();
typedef _CoCreateInstanceNative =
    Int32 Function(
      Pointer<GUID>,
      Pointer,
      Uint32,
      Pointer<GUID>,
      Pointer<Pointer<COMObject>>,
    );
typedef _CoCreateInstanceDart =
    int Function(
      Pointer<GUID>,
      Pointer,
      int,
      Pointer<GUID>,
      Pointer<Pointer<COMObject>>,
    );

typedef _QueryInterfaceNative =
    Int32 Function(
      Pointer<COMObject>,
      Pointer<GUID>,
      Pointer<Pointer<COMObject>>,
    );
typedef _QueryInterfaceDart =
    int Function(
      Pointer<COMObject>,
      Pointer<GUID>,
      Pointer<Pointer<COMObject>>,
    );
typedef _ReleaseNative = Uint32 Function(Pointer<COMObject>);
typedef _ReleaseDart = int Function(Pointer<COMObject>);
typedef _LoadNative = Int32 Function(Pointer<COMObject>, Pointer<Utf16>, Uint32);
typedef _LoadDart = int Function(Pointer<COMObject>, Pointer<Utf16>, int);
typedef _GetPathNative =
    Int32 Function(
      Pointer<COMObject>,
      Pointer<Utf16>,
      Int32,
      Pointer,
      Uint32,
    );
typedef _GetPathDart =
    int Function(Pointer<COMObject>, Pointer<Utf16>, int, Pointer, int);
typedef _GetIconLocationNative =
    Int32 Function(
      Pointer<COMObject>,
      Pointer<Utf16>,
      Int32,
      Pointer<Int32>,
    );
typedef _GetIconLocationDart =
    int Function(Pointer<COMObject>, Pointer<Utf16>, int, Pointer<Int32>);

typedef PrivateExtractIconsNative =
    Uint32 Function(
      Pointer<Utf16>,
      Int32,
      Int32,
      Int32,
      Pointer<IntPtr>,
      Pointer<Uint32>,
      Uint32,
      Uint32,
    );
typedef PrivateExtractIconsDart =
    int Function(
      Pointer<Utf16>,
      int,
      int,
      int,
      Pointer<IntPtr>,
      Pointer<Uint32>,
      int,
      int,
    );

typedef ExtractIconExNative =
    Uint32 Function(
      Pointer<Utf16>,
      Int32,
      Pointer<IntPtr>,
      Pointer<IntPtr>,
      Uint32,
    );
typedef ExtractIconExDart =
    int Function(
      Pointer<Utf16>,
      int,
      Pointer<IntPtr>,
      Pointer<IntPtr>,
      int,
    );

typedef SHGetFileInfoNative =
    IntPtr Function(
      Pointer<Utf16>,
      Uint32,
      Pointer<SHFILEINFOW>,
      Uint32,
      Uint32,
    );
typedef SHGetFileInfoDart =
    int Function(Pointer<Utf16>, int, Pointer<SHFILEINFOW>, int, int);

typedef DestroyIconNative = Int32 Function(IntPtr);
typedef DestroyIconDart = int Function(int);
typedef GetDCNative = IntPtr Function(IntPtr);
typedef GetDCDart = int Function(int);
typedef ReleaseDCNative = Int32 Function(IntPtr, IntPtr);
typedef ReleaseDCDart = int Function(int, int);
typedef CreateCompatibleDCNative = IntPtr Function(IntPtr);
typedef CreateCompatibleDCDart = int Function(int);
typedef DeleteDCNative = Int32 Function(IntPtr);
typedef DeleteDCDart = int Function(int);
typedef CreateDIBSectionNative =
    IntPtr Function(
      IntPtr,
      Pointer<BITMAPINFO>,
      Uint32,
      Pointer<Pointer<Uint8>>,
      IntPtr,
      Uint32,
    );
typedef CreateDIBSectionDart =
    int Function(
      int,
      Pointer<BITMAPINFO>,
      int,
      Pointer<Pointer<Uint8>>,
      int,
      int,
    );
typedef SelectObjectNative = IntPtr Function(IntPtr, IntPtr);
typedef SelectObjectDart = int Function(int, int);
typedef DeleteObjectNative = Int32 Function(IntPtr);
typedef DeleteObjectDart = int Function(int);
typedef DrawIconExNative =
    Int32 Function(
      IntPtr,
      Int32,
      Int32,
      IntPtr,
      Int32,
      Int32,
      Uint32,
      IntPtr,
      Uint32,
    );
typedef DrawIconExDart =
    int Function(int, int, int, int, int, int, int, int, int);

class _Win32IconApis {
  _Win32IconApis({
    required this.destroyIcon,
    required this.getDC,
    required this.releaseDC,
    required this.createCompatibleDC,
    required this.deleteDC,
    required this.createDIBSection,
    required this.selectObject,
    required this.deleteObject,
    required this.drawIconEx,
    this.privateExtractIcons,
    this.extractIconEx,
    this.shGetFileInfo,
    this.coInitializeEx,
    this.coUninitialize,
    this.coCreateInstance,
  });

  final DestroyIconDart destroyIcon;
  final GetDCDart getDC;
  final ReleaseDCDart releaseDC;
  final CreateCompatibleDCDart createCompatibleDC;
  final DeleteDCDart deleteDC;
  final CreateDIBSectionDart createDIBSection;
  final SelectObjectDart selectObject;
  final DeleteObjectDart deleteObject;
  final DrawIconExDart drawIconEx;
  final PrivateExtractIconsDart? privateExtractIcons;
  final ExtractIconExDart? extractIconEx;
  final SHGetFileInfoDart? shGetFileInfo;
  final _CoInitializeExDart? coInitializeEx;
  final _CoUninitializeDart? coUninitialize;
  final _CoCreateInstanceDart? coCreateInstance;

  static _Win32IconApis bind() {
    final user32 = DynamicLibrary.open('user32.dll');
    final gdi32 = DynamicLibrary.open('gdi32.dll');
    final shell32 = DynamicLibrary.open('shell32.dll');
    DynamicLibrary? ole32;
    try {
      ole32 = DynamicLibrary.open('ole32.dll');
    } catch (_) {
      ole32 = null;
    }

    PrivateExtractIconsDart? privateExtractIcons;
    try {
      privateExtractIcons = user32
          .lookup<NativeFunction<PrivateExtractIconsNative>>(
            'PrivateExtractIconsW',
          )
          .asFunction();
    } catch (_) {
      privateExtractIcons = null;
    }

    ExtractIconExDart? extractIconEx;
    try {
      extractIconEx = shell32
          .lookup<NativeFunction<ExtractIconExNative>>('ExtractIconExW')
          .asFunction();
    } catch (_) {
      extractIconEx = null;
    }

    SHGetFileInfoDart? shGetFileInfo;
    try {
      shGetFileInfo = shell32
          .lookup<NativeFunction<SHGetFileInfoNative>>('SHGetFileInfoW')
          .asFunction();
    } catch (_) {
      shGetFileInfo = null;
    }

    _CoInitializeExDart? coInitializeEx;
    _CoUninitializeDart? coUninitialize;
    _CoCreateInstanceDart? coCreateInstance;
    if (ole32 != null) {
      try {
        coInitializeEx = ole32
            .lookup<NativeFunction<_CoInitializeExNative>>('CoInitializeEx')
            .asFunction();
        coUninitialize = ole32
            .lookup<NativeFunction<_CoUninitializeNative>>('CoUninitialize')
            .asFunction();
        coCreateInstance = ole32
            .lookup<NativeFunction<_CoCreateInstanceNative>>('CoCreateInstance')
            .asFunction();
      } catch (_) {
        coInitializeEx = null;
        coUninitialize = null;
        coCreateInstance = null;
      }
    }

    return _Win32IconApis(
      destroyIcon: user32
          .lookup<NativeFunction<DestroyIconNative>>('DestroyIcon')
          .asFunction(),
      getDC: user32.lookup<NativeFunction<GetDCNative>>('GetDC').asFunction(),
      releaseDC: user32
          .lookup<NativeFunction<ReleaseDCNative>>('ReleaseDC')
          .asFunction(),
      createCompatibleDC: gdi32
          .lookup<NativeFunction<CreateCompatibleDCNative>>(
            'CreateCompatibleDC',
          )
          .asFunction(),
      deleteDC: gdi32
          .lookup<NativeFunction<DeleteDCNative>>('DeleteDC')
          .asFunction(),
      createDIBSection: gdi32
          .lookup<NativeFunction<CreateDIBSectionNative>>('CreateDIBSection')
          .asFunction(),
      selectObject: gdi32
          .lookup<NativeFunction<SelectObjectNative>>('SelectObject')
          .asFunction(),
      deleteObject: gdi32
          .lookup<NativeFunction<DeleteObjectNative>>('DeleteObject')
          .asFunction(),
      drawIconEx: user32
          .lookup<NativeFunction<DrawIconExNative>>('DrawIconEx')
          .asFunction(),
      privateExtractIcons: privateExtractIcons,
      extractIconEx: extractIconEx,
      shGetFileInfo: shGetFileInfo,
      coInitializeEx: coInitializeEx,
      coUninitialize: coUninitialize,
      coCreateInstance: coCreateInstance,
    );
  }
}

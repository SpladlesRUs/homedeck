import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';

/// Emulated-tile console / system. Chosen in Add or inferred from emulator/ROM.
enum ConsoleSystem {
  nes,
  snes,
  n64,
  gamecube,
  wii,
  wiiu,
  gb,
  gba,
  nds,
  n3ds,
  ps1,
  ps2,
  ps3,
  psp,
  genesis,
  saturn,
  dreamcast,
  xbox,
  xbox360,
  arcade,
  other;

  String get wireName => name;

  /// Filename slug for a later original platform-icon PNG (not shipped yet).
  String get slug => switch (this) {
    ConsoleSystem.nes => 'nes',
    ConsoleSystem.snes => 'snes',
    ConsoleSystem.n64 => 'nintendo-64',
    ConsoleSystem.gamecube => 'gamecube',
    ConsoleSystem.wii => 'wii',
    ConsoleSystem.wiiu => 'wii-u',
    ConsoleSystem.gb => 'game-boy',
    ConsoleSystem.gba => 'game-boy-advance',
    ConsoleSystem.nds => 'nintendo-ds',
    ConsoleSystem.n3ds => 'nintendo-3ds',
    ConsoleSystem.ps1 => 'playstation',
    ConsoleSystem.ps2 => 'playstation-2',
    ConsoleSystem.ps3 => 'playstation-3',
    ConsoleSystem.psp => 'psp',
    ConsoleSystem.genesis => 'genesis',
    ConsoleSystem.saturn => 'saturn',
    ConsoleSystem.dreamcast => 'dreamcast',
    ConsoleSystem.xbox => 'xbox',
    ConsoleSystem.xbox360 => 'xbox-360',
    ConsoleSystem.arcade => 'arcade',
    ConsoleSystem.other => 'other',
  };

  String get label => switch (this) {
    ConsoleSystem.nes => 'NES',
    ConsoleSystem.snes => 'SNES',
    ConsoleSystem.n64 => 'Nintendo 64',
    ConsoleSystem.gamecube => 'GameCube',
    ConsoleSystem.wii => 'Wii',
    ConsoleSystem.wiiu => 'Wii U',
    ConsoleSystem.gb => 'Game Boy',
    ConsoleSystem.gba => 'Game Boy Advance',
    ConsoleSystem.nds => 'Nintendo DS',
    ConsoleSystem.n3ds => 'Nintendo 3DS',
    ConsoleSystem.ps1 => 'PlayStation',
    ConsoleSystem.ps2 => 'PlayStation 2',
    ConsoleSystem.ps3 => 'PlayStation 3',
    ConsoleSystem.psp => 'PSP',
    ConsoleSystem.genesis => 'Genesis',
    ConsoleSystem.saturn => 'Saturn',
    ConsoleSystem.dreamcast => 'Dreamcast',
    ConsoleSystem.xbox => 'Xbox',
    ConsoleSystem.xbox360 => 'Xbox 360',
    ConsoleSystem.arcade => 'Arcade',
    ConsoleSystem.other => 'Other',
  };

  static ConsoleSystem fromWire(String? value) {
    if (value == null || value.isEmpty) {
      return ConsoleSystem.other;
    }
    for (final item in ConsoleSystem.values) {
      if (item.name == value) {
        return item;
      }
    }
    return ConsoleSystem.other;
  }
}

/// Native-tile store / launcher. Inferred from URI or path, editable in Add.
enum Storefront {
  steam,
  gog,
  epic,
  ea,
  xbox,
  battlenet,
  ubisoft,
  other;

  String get wireName => name;

  String get slug => name;

  String get label => switch (this) {
    Storefront.steam => 'Steam',
    Storefront.gog => 'GOG',
    Storefront.epic => 'Epic',
    Storefront.ea => 'Origin / EA app',
    Storefront.xbox => 'Xbox / Microsoft Store',
    Storefront.battlenet => 'Battle.net',
    Storefront.ubisoft => 'Ubisoft Connect',
    Storefront.other => 'Other / Standalone',
  };

  static Storefront fromWire(String? value) {
    if (value == null || value.isEmpty) {
      return Storefront.other;
    }
    for (final item in Storefront.values) {
      if (item.name == value) {
        return item;
      }
    }
    return Storefront.other;
  }
}

/// Library grouping axis: emulated-by-console vs native-by-store.
enum LibraryGroupMode {
  console,
  store;

  String get label => switch (this) {
    LibraryGroupMode.console => 'By console',
    LibraryGroupMode.store => 'By app',
  };
}

class SourceInference {
  SourceInference._();

  static Storefront storeFor(LaunchTarget target) {
    return storeFrom(target.value);
  }

  static Storefront storeFrom(String raw) {
    final value = raw.toLowerCase();
    if (value.startsWith('steam:') ||
        value.contains(r'\steam\') ||
        value.contains('/steam/') ||
        value.contains('steamapps')) {
      return Storefront.steam;
    }
    if (value.startsWith('goggalaxy:') ||
        value.contains('gog galaxy') ||
        value.contains(r'\gog') ||
        value.contains('/gog')) {
      return Storefront.gog;
    }
    if (value.startsWith('com.epicgames.launcher:') ||
        value.contains('epic games') ||
        value.contains(r'\epicgames') ||
        value.contains('epicgameslauncher')) {
      return Storefront.epic;
    }
    if (value.startsWith('origin:') ||
        value.startsWith('eaapp:') ||
        value.contains(r'\origin') ||
        value.contains('ea desktop') ||
        value.contains(r'\ea games') ||
        value.contains('electronic arts')) {
      return Storefront.ea;
    }
    if (value.startsWith('msxbox:') ||
        value.startsWith('xbox:') ||
        value.startsWith('ms-windows-store:') ||
        value.contains('windowsapps') ||
        value.contains(r'\xbox') ||
        value.contains('xbox games')) {
      return Storefront.xbox;
    }
    if (value.startsWith('battlenet:') ||
        value.contains('battle.net') ||
        value.contains('battlenet')) {
      return Storefront.battlenet;
    }
    if (value.startsWith('uplay:') ||
        value.startsWith('ubisoftconnect:') ||
        value.contains('ubisoft') ||
        value.contains(r'\uplay')) {
      return Storefront.ubisoft;
    }
    return Storefront.other;
  }

  static ConsoleSystem consoleFor(LaunchTarget target) {
    return consoleFrom(
      emulatorPath: target.value,
      romPath: target.romPath,
      argsTemplate: target.argsTemplate,
    );
  }

  static ConsoleSystem consoleFrom({
    String? emulatorPath,
    String? romPath,
    String? argsTemplate,
  }) {
    final blob = [
      emulatorPath ?? '',
      romPath ?? '',
      argsTemplate ?? '',
    ].join(' ').toLowerCase();

    ConsoleSystem? fromExt(String? path) {
      if (path == null || path.isEmpty) {
        return null;
      }
      return switch (WindowsPaths.extension(path)) {
        '.nes' => ConsoleSystem.nes,
        '.smc' || '.sfc' => ConsoleSystem.snes,
        '.n64' || '.z64' || '.v64' => ConsoleSystem.n64,
        '.gba' => ConsoleSystem.gba,
        '.gb' || '.gbc' => ConsoleSystem.gb,
        '.nds' => ConsoleSystem.nds,
        '.3ds' || '.cia' => ConsoleSystem.n3ds,
        '.gen' || '.md' || '.smd' => ConsoleSystem.genesis,
        '.cdi' || '.gdi' => ConsoleSystem.dreamcast,
        '.gcm' ||
        '.ciso' ||
        '.tgc' ||
        '.wbfs' ||
        '.wad' => ConsoleSystem.gamecube,
        _ => null,
      };
    }

    final romExt = fromExt(romPath);
    if (romExt != null) {
      return romExt;
    }

    bool has(String token) => blob.contains(token);

    if (has('snes9x') || has('bsnes') || has('mesen-s') || has('snes')) {
      return ConsoleSystem.snes;
    }
    if (has('nestopia') || has('fceux') || has('mesen') || has('nes')) {
      return ConsoleSystem.nes;
    }
    if (has('mupen') || has('project64') || has('n64') || has('nintendo 64')) {
      return ConsoleSystem.n64;
    }
    if (has('cemu') || has('wiiu') || has('wii u')) {
      return ConsoleSystem.wiiu;
    }
    if (has('dolphin')) {
      if (has('wii') && !has('wiiu')) {
        return ConsoleSystem.wii;
      }
      return ConsoleSystem.gamecube;
    }
    if (has('pcsx2') || has('ps2') || has('playstation 2')) {
      return ConsoleSystem.ps2;
    }
    if (has('rpcs3') || has('ps3') || has('playstation 3')) {
      return ConsoleSystem.ps3;
    }
    if (has('ppsspp') || has('psp')) {
      return ConsoleSystem.psp;
    }
    if (has('duckstation') ||
        has('pcsx') ||
        has('epsxe') ||
        has('ps1') ||
        has('psx') ||
        has('playstation')) {
      return ConsoleSystem.ps1;
    }
    if (has('mgba') || has('visualboy') || has('vbam') || has('gba')) {
      return ConsoleSystem.gba;
    }
    if (has('sameboy') || has('bgb') || has('gameboy') || has('game boy')) {
      return ConsoleSystem.gb;
    }
    if (has('desmume') || has('melonds') || has('nds')) {
      return ConsoleSystem.nds;
    }
    if (has('citra') || has('lime3ds') || has('3ds')) {
      return ConsoleSystem.n3ds;
    }
    if (has('blastem') ||
        has('gens') ||
        has('fusion') ||
        has('genesis') ||
        has('megadrive')) {
      return ConsoleSystem.genesis;
    }
    if (has('mednafen') && has('ss')) {
      return ConsoleSystem.saturn;
    }
    if (has('yaba') || has('saturn')) {
      return ConsoleSystem.saturn;
    }
    if (has('flycast') || has('redream') || has('demul') || has('dreamcast')) {
      return ConsoleSystem.dreamcast;
    }
    if (has('xenia') || has('xbox360') || has('xbox 360')) {
      return ConsoleSystem.xbox360;
    }
    if (has('xemu') || has('xbox')) {
      return ConsoleSystem.xbox;
    }
    if (has('mame') || has('fbneo') || has('arcade')) {
      return ConsoleSystem.arcade;
    }
    return ConsoleSystem.other;
  }

  static String groupTitle({
    required TileKind kind,
    required LibraryGroupMode mode,
    ConsoleSystem? console,
    Storefront? store,
  }) {
    if (mode == LibraryGroupMode.console) {
      if (kind == TileKind.emulated) {
        return (console ?? ConsoleSystem.other).label;
      }
      return 'Native';
    }
    if (kind == TileKind.native) {
      return (store ?? Storefront.other).label;
    }
    return 'Emulated';
  }
}

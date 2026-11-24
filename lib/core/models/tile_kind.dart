/// How a library tile is launched on this device.
///
/// Native: a Windows `.exe`, `.lnk`, or store URI (`steam://…`).
/// Emulated: an emulator executable plus a ROM path and an args template.
enum TileKind {
  native,
  emulated;

  String get wireName => name;

  static TileKind fromWire(String? value) {
    if (value == null || value.isEmpty) {
      return TileKind.native;
    }
    for (final kind in TileKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }
    throw FormatException('Unknown TileKind: $value');
  }
}

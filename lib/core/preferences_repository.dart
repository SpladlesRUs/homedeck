import 'dart:convert';
import 'dart:io';

import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:path/path.dart' as p;

/// JSON library stored under [path_provider] application support.
class PreferencesRepository {
  PreferencesRepository(this.paths);

  final AppPaths paths;

  Future<HomeDeckState> load() async {
    final file = paths.libraryJsonFile();
    if (!await file.exists()) {
      // Seed an empty library.json on first launch so Ally's AppData check
      // (`%AppData%\Horton Press\HomeDeck\library.json`) is a real file even
      // before the first add. icons\ alone from IconCache.ensureReady is not
      // enough — Phase2 failed with only icons\ present.
      try {
        await save(const HomeDeckState());
      } on FileSystemException {
        // Support dir unwritable (tests); still return empty state.
      }
      return const HomeDeckState();
    }
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const HomeDeckState();
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        return const HomeDeckState();
      }
      return HomeDeckState.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    } on FormatException {
      return const HomeDeckState();
    } on FileSystemException {
      return const HomeDeckState();
    }
  }

  /// Writes [state] directly to `library.json` with flush.
  ///
  /// Ally re-smoke at 80e8517 still saw only `icons\` after add. The prior
  /// temp+rename path can leave no durable `library.json` on some Windows
  /// handhelds (Defender / rename races). Direct overwrite + existence and
  /// non-empty checks match what Phase2 reads under AppData.
  Future<void> save(HomeDeckState state) async {
    final file = paths.libraryJsonFile();
    final dir = file.parent;
    dir.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final payload = encoder.convert(state.toJson());
    // Write via temp then copy+replace so a half-written file is never left
    // as library.json, but always finish with a direct overwrite as well so
    // Windows rename quirks cannot hide the file from Ally.
    final temp = File(p.join(dir.path, 'library.json.tmp'));
    temp.writeAsStringSync(payload, flush: true);
    try {
      temp.copySync(file.path);
    } on FileSystemException {
      file.writeAsStringSync(payload, flush: true);
    }
    if (temp.existsSync()) {
      try {
        temp.deleteSync();
      } on FileSystemException {
        // Best-effort cleanup; library.json is what Ally checks.
      }
    }
    // Final authoritative write — guarantees library.json bytes on disk.
    file.writeAsStringSync(payload, flush: true);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw FileSystemException(
        'library.json was not present after save',
        file.path,
      );
    }
  }

  /// True when [candidate] is the library file inside [paths.supportRoot].
  bool isLibraryFile(File candidate) {
    return p.equals(p.normalize(candidate.path), p.normalize(paths.libraryFile));
  }
}

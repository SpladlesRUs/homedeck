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

  /// Writes [state] via a temp file then replaces `library.json`.
  ///
  /// Ally smoke at 27ba8ec saw `icons\` under AppData with no `library.json`
  /// after a successful add. Icons are written before this save; a failed or
  /// non-durable write left the PNG cache without the library file. We flush
  /// the temp file and only then replace the destination so the final name
  /// appears with complete JSON.
  Future<void> save(HomeDeckState state) async {
    final file = paths.libraryJsonFile();
    final dir = file.parent;
    await dir.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final payload = encoder.convert(state.toJson());
    final temp = File(p.join(dir.path, 'library.json.tmp'));
    await temp.writeAsString(payload, flush: true);
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } on FileSystemException {
      // Windows sometimes refuses rename-over; copy then remove temp.
      await temp.copy(file.path);
      if (await temp.exists()) {
        await temp.delete();
      }
    }
    if (!await file.exists()) {
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

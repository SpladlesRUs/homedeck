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

  Future<void> save(HomeDeckState state) async {
    final file = paths.libraryJsonFile();
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(state.toJson()), flush: true);
  }

  /// True when [candidate] is the library file inside [paths.supportRoot].
  bool isLibraryFile(File candidate) {
    return p.equals(p.normalize(candidate.path), p.normalize(paths.libraryFile));
  }
}

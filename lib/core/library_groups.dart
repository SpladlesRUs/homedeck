import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/game_source.dart';

class LibrarySection {
  const LibrarySection({required this.title, required this.apps});

  final String title;
  final List<AppRecord> apps;
}

List<LibrarySection> groupLibrary(
  List<AppRecord> apps, {
  required LibraryGroupMode mode,
}) {
  final buckets = <String, List<AppRecord>>{};
  for (final app in apps) {
    final title = SourceInference.groupTitle(
      kind: app.kind,
      mode: mode,
      console: app.console,
      store: app.store,
    );
    buckets.putIfAbsent(title, () => []).add(app);
  }
  for (final list in buckets.values) {
    list.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  }
  final order = mode == LibraryGroupMode.console
      ? <String>[
          for (final console in ConsoleSystem.values) console.label,
          'Native',
        ]
      : <String>[
          for (final store in Storefront.values) store.label,
          'Emulated',
        ];
  return [
    for (final title in order)
      if (buckets[title] != null && buckets[title]!.isNotEmpty)
        LibrarySection(
          title: title,
          apps: List<AppRecord>.unmodifiable(buckets[title]!),
        ),
  ];
}

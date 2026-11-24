import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/home_pager.dart';
import 'package:homedeck/ui/now_playing_tile.dart';
import 'package:homedeck/ui/platform_folder.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final metrics = HomeDeckMetrics.of(const Size(1280, 800));

  test('empty Home still has two pages', () {
    expect(HomePager.pageCount(lastOccupiedIndex: -1, metrics: metrics), 2);
    expect(HomePager.slotCount(2, metrics), 15 + 21);
  });

  test('page 1 focus ids start with the featured tile', () {
    final ids = HomePager.focusIdsForPage(
      page: 0,
      slots: const [],
      metrics: metrics,
    );
    expect(ids.first, nowPlayingId);
    expect(ids, hasLength(16));
    expect(ids[1], emptySlotId(0));
  });

  test('a page change always lands on a visible tile', () {
    final slots = List<String?>.filled(40, null);
    slots[0] = 'app-1';
    slots[15] = 'app-16';
    final id = HomePager.focusedIdAfterPageChange(
      page: 1,
      slots: slots,
      metrics: metrics,
      row: 0,
    );
    expect(
      HomePager.focusIdsForPage(page: 1, slots: slots, metrics: metrics),
      contains(id),
    );
    expect(id, 'app-16');
  });

  test('platform icon hook is empty until Tre ships PNGs', () {
    expect(metrics.libraryFolderColumns, 5);
    expect(metrics.insideFolderColumns, 3);
    expect(platformIconAsset('nes'), isNull);
    expect(platformIconAsset('arcade'), isNull);
  });
}

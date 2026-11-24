import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/now_playing_tile.dart';

/// WiiSU-style Home pages: featured + 5×3 on page 1, 7×3 later, never fewer
/// than two pages. Empty slots stay in place.
class HomePager {
  HomePager._();

  static const minPages = 2;

  static int pageCount({
    required int lastOccupiedIndex,
    required HomeDeckMetrics metrics,
    int extraPages = 0,
  }) {
    final occupied = lastOccupiedIndex < 0 ? 0 : lastOccupiedIndex + 1;
    var pages = 1;
    if (occupied > metrics.page1PinCount) {
      final extra = occupied - metrics.page1PinCount;
      pages =
          1 + ((extra + metrics.laterPageSize - 1) ~/ metrics.laterPageSize);
    }
    final min = minPages + extraPages;
    return pages < min ? min : pages;
  }

  static int pageStart(int page, HomeDeckMetrics metrics) =>
      metrics.homePageStart(page);

  static int pageSize(int page, HomeDeckMetrics metrics) =>
      metrics.homePageSize(page);

  static int columns(int page, HomeDeckMetrics metrics) =>
      metrics.homeColumns(page);

  static int slotCount(int pages, HomeDeckMetrics metrics) =>
      metrics.homeSlotCount(pages);

  static List<String> focusIdsForPage({
    required int page,
    required List<String?> slots,
    required HomeDeckMetrics metrics,
  }) {
    final start = pageStart(page, metrics);
    final size = pageSize(page, metrics);
    final pins = [
      for (var i = 0; i < size; i++)
        (start + i < slots.length ? slots[start + i] : null) ??
            emptySlotId(start + i),
    ];
    if (page <= 0) {
      return [nowPlayingId, ...pins];
    }
    return pins;
  }

  /// After a page change, focus a tile that is actually on the new page.
  static String focusedIdAfterPageChange({
    required int page,
    required List<String?> slots,
    required HomeDeckMetrics metrics,
    String? preferredId,
    int? row,
    bool fromRight = false,
  }) {
    final ids = focusIdsForPage(page: page, slots: slots, metrics: metrics);
    if (preferredId != null && ids.contains(preferredId)) {
      return preferredId;
    }
    final cols = columns(page, metrics);
    if (page > 0) {
      final r = (row ?? 0).clamp(0, metrics.rows - 1);
      final col = fromRight ? cols - 1 : 0;
      final index = r * cols + col;
      if (index >= 0 && index < ids.length) {
        return ids[index];
      }
    }
    if (fromRight && page <= 0) {
      final r = (row ?? 0).clamp(0, metrics.rows - 1);
      final index = 1 + r * cols + (cols - 1);
      if (index >= 0 && index < ids.length) {
        return ids[index];
      }
    }
    return ids.first;
  }

  static int pageOfSlot(int slot, HomeDeckMetrics metrics) {
    if (slot < metrics.page1PinCount) {
      return 0;
    }
    return 1 + (slot - metrics.page1PinCount) ~/ metrics.laterPageSize;
  }
}

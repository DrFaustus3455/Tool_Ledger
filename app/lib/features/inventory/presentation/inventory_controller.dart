import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/workspace_controller.dart';
import '../data/models/tool_asset.dart';

enum InventorySort {
  assetId,
  description,
  status,
  department,
  purchaseDate,
  netBookValue,
}

enum InventoryView { table, cards }

class InventoryFilter {
  const InventoryFilter({
    this.query = '',
    this.status,
    this.department,
    this.category,
    this.sort = InventorySort.assetId,
    this.ascending = true,
    this.page = 0,
    this.pageSize = 8,
    this.view = InventoryView.table,
    this.selectedIds = const {},
  });
  final String query;
  final AssetStatus? status;
  final String? department;
  final String? category;
  final InventorySort sort;
  final bool ascending;
  final int page;
  final int pageSize;
  final InventoryView view;
  final Set<String> selectedIds;

  InventoryFilter copyWith({
    String? query,
    Object? status = _unset,
    Object? department = _unset,
    Object? category = _unset,
    InventorySort? sort,
    bool? ascending,
    int? page,
    int? pageSize,
    InventoryView? view,
    Set<String>? selectedIds,
  }) => InventoryFilter(
    query: query ?? this.query,
    status: identical(status, _unset) ? this.status : status as AssetStatus?,
    department: identical(department, _unset)
        ? this.department
        : department as String?,
    category: identical(category, _unset) ? this.category : category as String?,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    view: view ?? this.view,
    selectedIds: selectedIds ?? this.selectedIds,
  );
}

const _unset = Object();

final inventoryFilterProvider =
    NotifierProvider<InventoryController, InventoryFilter>(
      InventoryController.new,
    );

class InventoryController extends Notifier<InventoryFilter> {
  @override
  InventoryFilter build() => const InventoryFilter();
  void search(String value) => state = state.copyWith(query: value, page: 0);
  void status(AssetStatus? value) =>
      state = state.copyWith(status: value, page: 0);
  void department(String? value) =>
      state = state.copyWith(department: value, page: 0);
  void category(String? value) =>
      state = state.copyWith(category: value, page: 0);
  void sort(InventorySort value) => state = state.copyWith(
    sort: value,
    ascending: state.sort == value ? !state.ascending : true,
    page: 0,
  );
  void page(int value) => state = state.copyWith(page: value);
  void view(InventoryView value) => state = state.copyWith(view: value);
  void reset() => state = const InventoryFilter();
  void toggleSelected(String id) {
    final values = {...state.selectedIds};
    values.contains(id) ? values.remove(id) : values.add(id);
    state = state.copyWith(selectedIds: values);
  }

  void clearSelection() => state = state.copyWith(selectedIds: const {});
}

final filteredAssetsProvider = Provider<List<ToolAsset>>((ref) {
  final filter = ref.watch(inventoryFilterProvider);
  final data = ref.watch(workspaceProvider).value;
  if (data == null) return const [];
  final query = filter.query.trim().toLowerCase();
  final results = data.assets.where((asset) {
    final matchesQuery =
        query.isEmpty ||
        [
          asset.id,
          asset.serialNumber,
          asset.description,
          asset.partNumber,
          asset.manufacturer,
          asset.currentBorrower,
        ].any((v) => v.toLowerCase().contains(query));
    return matchesQuery &&
        (filter.status == null || asset.status == filter.status) &&
        (filter.department == null || asset.department == filter.department) &&
        (filter.category == null || asset.equipmentType == filter.category);
  }).toList();
  int compare(ToolAsset a, ToolAsset b) => switch (filter.sort) {
    InventorySort.assetId => a.id.compareTo(b.id),
    InventorySort.description => a.description.compareTo(b.description),
    InventorySort.status => a.status.index.compareTo(b.status.index),
    InventorySort.department => a.department.compareTo(b.department),
    InventorySort.purchaseDate => a.purchaseDate.compareTo(b.purchaseDate),
    InventorySort.netBookValue => a.netBookValue.compareTo(b.netBookValue),
  };
  results.sort((a, b) => filter.ascending ? compare(a, b) : compare(b, a));
  return results;
});

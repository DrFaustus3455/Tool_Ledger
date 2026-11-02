import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/asset_photo.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/workspace_data.dart';
import '../../auth/presentation/session_controller.dart';
import '../../reports/data/excel_export_service.dart';
import '../../reports/presentation/export_dialog.dart';
import '../data/models/tool_asset.dart';
import 'asset_profile.dart';
import 'inventory_controller.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(label: 'Indexing asset registry…'),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) => _InventoryView(data: data),
    );
  }
}

class _InventoryView extends ConsumerWidget {
  const _InventoryView({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inventoryFilterProvider);
    final controller = ref.read(inventoryFilterProvider.notifier);
    final assets = ref.watch(filteredAssetsProvider);
    final user = ref.watch(sessionProvider).user!;
    final pageCount = (assets.length / filter.pageSize).ceil().clamp(
      1,
      1000000,
    );
    final page = filter.page.clamp(0, pageCount - 1);
    final visible = assets
        .skip(page * filter.pageSize)
        .take(filter.pageSize)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Inventory master',
                subtitle:
                    '${assets.length} matching assets • ${data.assets.length} physical records • unique QR identity per unit',
                eyebrow: 'ASSET REGISTRY / LEGACY PRESERVED',
                actions: [
                  if (user.role == UserRole.manager) ...[
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const RegisterAssetDialog(),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Register equipment'),
                    ),
                    FilledButton.icon(
                      onPressed: () => showExportDialog(
                        context,
                        preset: filter.selectedIds.isNotEmpty
                            ? ExportDataset.selectedEquipment
                            : ExportDataset.filteredResults,
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('EXPORT TO EXCEL'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: filter.query,
                            onChanged: controller.search,
                            decoration: const InputDecoration(
                              hintText: 'Search asset ID, serial, description, part, borrower…',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Reset all filters',
                          onPressed: controller.reset,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                        ),
                        IconButton(
                          tooltip: 'Table view',
                          isSelected: filter.view == InventoryView.table,
                          onPressed: () => controller.view(InventoryView.table),
                          icon: const Icon(Icons.table_rows_outlined),
                        ),
                        IconButton(
                          tooltip: 'Card view',
                          isSelected: filter.view == InventoryView.cards,
                          onPressed: () => controller.view(InventoryView.cards),
                          icon: const Icon(Icons.grid_view_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<AssetStatus>(
                            initialValue: filter.status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                child: Text(
                                  'All statuses',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...AssetStatus.values.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: controller.status,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: filter.department,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                child: Text(
                                  'All departments',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...data.assets
                                  .map((a) => a.department)
                                  .toSet()
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: controller.department,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: filter.category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Equipment type',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                child: Text(
                                  'All categories',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...data.assets
                                  .map((a) => a.equipmentType)
                                  .toSet()
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: controller.category,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (filter.selectedIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: context.colors.elevated,
                  child: Row(
                    children: [
                      Text(
                        '${filter.selectedIds.length} selected',
                        style: monoStyle(
                          context,
                          size: 11,
                          color: context.colors.accent,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: controller.clearSelection,
                        child: const Text('Clear selection'),
                      ),
                      FilledButton(
                        onPressed: () => showExportDialog(
                          context,
                          preset: ExportDataset.selectedEquipment,
                        ),
                        child: const Text('Export selected'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (visible.isEmpty)
                EmptyState(
                  title: 'No equipment matches',
                  message:
                      'Adjust the search or filters to find another asset.',
                  action: OutlinedButton(
                    onPressed: controller.reset,
                    child: const Text('Reset filters'),
                  ),
                )
              else if (filter.view == InventoryView.table)
                _AssetTable(
                  assets: visible,
                  filter: filter,
                  controller: controller,
                  manager: user.role == UserRole.manager,
                )
              else
                _AssetCards(
                  assets: visible,
                  manager: user.role == UserRole.manager,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Showing ${assets.isEmpty ? 0 : page * filter.pageSize + 1}–${(page * filter.pageSize + visible.length)} of ${assets.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: page > 0
                        ? () => controller.page(page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'PAGE ${page + 1} / $pageCount',
                    style: monoStyle(context, size: 10),
                  ),
                  IconButton(
                    onPressed: page < pageCount - 1
                        ? () => controller.page(page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetTable extends StatelessWidget {
  const _AssetTable({
    required this.assets,
    required this.filter,
    required this.controller,
    required this.manager,
  });
  final List<ToolAsset> assets;
  final InventoryFilter filter;
  final InventoryController controller;
  final bool manager;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1180),
          child: DataTable(
            showCheckboxColumn: manager,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            sortColumnIndex: InventorySort.values.indexOf(filter.sort),
            sortAscending: filter.ascending,
            columns: [
              DataColumn(
                label: const Text('ASSET / SERIAL'),
                onSort: (_, _) => controller.sort(InventorySort.assetId),
              ),
              DataColumn(
                label: const Text('DESCRIPTION'),
                onSort: (_, _) => controller.sort(InventorySort.description),
              ),
              DataColumn(
                label: const Text('STATUS'),
                onSort: (_, _) => controller.sort(InventorySort.status),
              ),
              DataColumn(
                label: const Text('DEPARTMENT'),
                onSort: (_, _) => controller.sort(InventorySort.department),
              ),
              const DataColumn(label: Text('LOCATION / BORROWER')),
              DataColumn(
                label: const Text('PURCHASE DATE'),
                onSort: (_, _) => controller.sort(InventorySort.purchaseDate),
              ),
              if (manager)
                DataColumn(
                  label: const Text('NET BOOK VALUE'),
                  numeric: true,
                  onSort: (_, _) => controller.sort(InventorySort.netBookValue),
                ),
            ],
            rows: assets
                .map(
                  (asset) => DataRow(
                    selected: filter.selectedIds.contains(asset.id),
                    onSelectChanged: manager
                        ? (_) => controller.toggleSelected(asset.id)
                        : null,
                    cells: [
                      DataCell(
                        onTap: () => showAssetProfile(context, asset.id),
                        Row(
                          children: [
                            AssetPhoto(
                              url: asset.photoUrl,
                              label: asset.id,
                              width: 48,
                              height: 44,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.id,
                                  style: monoStyle(
                                    context,
                                    size: 11,
                                    color: context.colors.accent,
                                  ),
                                ),
                                Text(
                                  asset.serialNumber,
                                  style: monoStyle(
                                    context,
                                    size: 9,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        onTap: () => showAssetProfile(context, asset.id),
                        SizedBox(
                          width: 230,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${asset.manufacturer} • ${asset.equipmentType}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(StatusBadge.asset(asset.status, compact: true)),
                      DataCell(Text(asset.department)),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.lyingAt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                asset.currentBorrower.isEmpty
                                    ? asset.condition
                                    : asset.currentBorrower,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          DateFormat('dd MMM yyyy').format(asset.purchaseDate),
                          style: monoStyle(context, size: 10),
                        ),
                      ),
                      if (manager)
                        DataCell(
                          Text(
                            money.format(asset.netBookValue),
                            style: monoStyle(context, size: 10),
                          ),
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _AssetCards extends ConsumerWidget {
  const _AssetCards({required this.assets, required this.manager});
  final List<ToolAsset> assets;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 1200
          ? 4
          : constraints.maxWidth > 800
          ? 3
          : constraints.maxWidth > 520
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: assets
            .map(
              (asset) => SizedBox(
                width: width,
                child: Material(
                  color: context.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: BorderSide(color: context.colors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => showAssetProfile(context, asset.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            AssetPhoto(
                              url: asset.photoUrl,
                              label: asset.description,
                              width: double.infinity,
                              height: 160,
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: StatusBadge.asset(
                                asset.status,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.id,
                                style: monoStyle(
                                  context,
                                  size: 10,
                                  color: context.colors.accent,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                asset.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${asset.manufacturer} • ${asset.equipmentType}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Divider(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      asset.department,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                  if (manager)
                                    Text(
                                      NumberFormat.compactCurrency(
                                        symbol: 'PKR ',
                                        decimalDigits: 0,
                                      ).format(asset.netBookValue),
                                      style: monoStyle(context, size: 10),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class RegisterAssetDialog extends ConsumerStatefulWidget {
  const RegisterAssetDialog({super.key});
  @override
  ConsumerState<RegisterAssetDialog> createState() =>
      _RegisterAssetDialogState();
}

class _RegisterAssetDialogState extends ConsumerState<RegisterAssetDialog> {
  final _form = GlobalKey<FormState>();
  final _values = <String, TextEditingController>{};
  DateTime _purchaseDate = DateTime.now();
  var _restricted = false;
  var _imported = true;
  var _loading = false;
  TextEditingController _c(String key, [String initial = '']) =>
      _values.putIfAbsent(key, () => TextEditingController(text: initial));
  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final now = DateTime.now();
    final price = double.parse(_c('price').text);
    final asset = ToolAsset(
      id: _c('id').text.trim().toUpperCase(),
      serialNumber: _c('serial').text.trim(),
      description: _c('description').text.trim(),
      quantity: 1,
      partNumber: _c('part').text.trim(),
      series: _c('series', 'Industrial').text.trim(),
      manufacturer: _c('manufacturer').text.trim(),
      equipmentType: _c('category').text.trim(),
      legacyTypePrimary: 'UNMAPPED',
      legacyTypeSecondary: 'UNMAPPED',
      legacyDepreciationPrimary: 0,
      legacyDepreciationSecondary: 0,
      unitPricePkr: price,
      extendedPricePkr: price,
      historicalGstAmountPkr: 0,
      historicalGstRate: 0,
      totalPurchaseValuePkr: price,
      foreignCurrencyValue: 0,
      foreignCurrencyCode: 'USD',
      purchaseDate: _purchaseDate,
      valuationDate: now,
      usefulLifeYears: int.parse(_c('life', '5').text),
      residualValuePkr: 0,
      historicalAccumulatedDepreciationPkr: 0,
      vendor: _c('vendor').text.trim(),
      isImported: _imported,
      oesPurchaseOrder: _c('po').text.trim(),
      billNumber: _c('bill').text.trim(),
      billDate: _purchaseDate,
      department: _c('department').text.trim(),
      lyingAt: _c('location').text.trim(),
      departmentCode: _c('code').text.trim(),
      condition: 'Serviceable',
      issuedTo: '',
      transferredTo: '',
      purpose: 'Registered for generator maintenance operations',
      remarks: 'New registration pending approval.',
      lastUpdated: now,
      currentBorrower: '',
      expectedReturnDate: null,
      status: AssetStatus.available,
      isRestricted: _restricted,
    );
    try {
      await ref
          .read(workspaceProvider.notifier)
          .registerAsset(asset, ref.read(sessionProvider).user!);
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(
          context,
          '${asset.id} submitted for manager approval. It is not active yet.',
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Register new equipment'),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One physical unit per asset ID. Registration remains pending until a manager approves it; legacy import headings remain explicitly unmapped.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field('id', 'Unique QR asset ID', width: 340),
                  _field('serial', 'Serial number', width: 340),
                  _field('description', 'Description', width: 692),
                  _field('part', 'Part number', width: 340),
                  _field('manufacturer', 'Manufacturer / make', width: 340),
                  _field('series', 'Series', width: 340, initial: 'Industrial'),
                  _field('category', 'Equipment type', width: 340),
                  _field(
                    'price',
                    'Total purchase value (PKR)',
                    width: 340,
                    numeric: true,
                  ),
                  _field(
                    'life',
                    'Useful life (years)',
                    width: 340,
                    initial: '5',
                    numeric: true,
                  ),
                  _field('vendor', 'Vendor', width: 340),
                  _field('po', 'OES purchase order', width: 340),
                  _field('bill', 'Bill number', width: 340),
                  _field('department', 'Project / department', width: 340),
                  _field('code', 'Department code', width: 340),
                  _field('location', 'Lying at', width: 340),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _purchaseDate = d);
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  'Purchase date: ${DateFormat('dd MMM yyyy').format(_purchaseDate)}',
                ),
              ),
              SwitchListTile(
                value: _imported,
                onChanged: (v) => setState(() => _imported = v),
                title: const Text('Imported equipment'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _restricted,
                onChanged: (v) => setState(() => _restricted = v),
                title: const Text('Restricted regardless of purchase value'),
                subtitle: const Text(
                  'High-value approval required before every handover.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: Text(_loading ? 'SUBMITTING…' : 'SUBMIT FOR APPROVAL'),
      ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    double width = 340,
    bool numeric = false,
    String? initial,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: _c(key, initial ?? ''),
      keyboardType: numeric ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (numeric && double.tryParse(v) == null) {
          return 'Enter a valid number';
        }
        if (key == 'id' && !RegExp(r'^[A-Za-z0-9-_]{5,40}$').hasMatch(v)) {
          return 'Use 5–40 letters, numbers, dashes';
        }
        return null;
      },
    ),
  );
}

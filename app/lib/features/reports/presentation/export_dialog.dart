import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_user.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../data/excel_export_service.dart';

Future<void> showExportDialog(
  BuildContext context, {
  ExportDataset? preset,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => ExportDialog(preset: preset),
  );
}

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key, this.preset});
  final ExportDataset? preset;
  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late ExportDataset _dataset = widget.preset ?? ExportDataset.completeWorkbook;
  String? _department;
  String? _category;
  AssetStatus? _status;
  DateTimeRange? _transactionRange;
  DateTimeRange? _purchaseRange;
  final _borrower = TextEditingController();
  var _loading = false;
  var _progress = 0.0;
  String? _confirmation;
  String? _error;
  final _service = const ExcelExportService();

  @override
  void dispose() {
    _borrower.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final data = ref.read(workspaceProvider).value;
    final user = ref.read(sessionProvider).user;
    if (data == null || user == null) return;
    setState(() {
      _loading = true;
      _progress = .15;
      _error = null;
      _confirmation = null;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 220));
      final filter = ref.read(inventoryFilterProvider);
      final result = _service.build(
        data,
        ExportOptions(
          dataset: _dataset,
          department: _department,
          category: _category,
          status: _status,
          startDate: _transactionRange?.start,
          endDate: _transactionRange?.end.add(const Duration(days: 1)),
          purchaseStart: _purchaseRange?.start,
          purchaseEnd: _purchaseRange?.end.add(const Duration(days: 1)),
          borrower: _borrower.text,
          selectedIds: filter.selectedIds,
          filteredIds: ref
              .read(filteredAssetsProvider)
              .map((a) => a.id)
              .toSet(),
        ),
        user,
      );
      if (mounted) setState(() => _progress = .72);
      await _service.download(result);
      if (mounted) {
        setState(() {
          _progress = 1;
          _confirmation =
              '${result.fileName}\n${result.recordCount} exported records • genuine XLSX workbook';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(workspaceProvider).value;
    final role = ref.watch(sessionProvider).user?.role ?? UserRole.lender;
    final datasets = ExportDataset.values
        .where(
          (d) =>
              role == UserRole.manager ||
              d == ExportDataset.activeLoans ||
              d == ExportDataset.lendingHistory,
        )
        .toList();
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.table_view_outlined, color: context.colors.accent),
          const SizedBox(width: 12),
          const Expanded(child: Text('Export to Excel')),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Generate a typed, formatted .xlsx workbook. Identifiers remain text and user-controlled values are protected against formula injection.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ExportDataset>(
                initialValue: _dataset,
                decoration: const InputDecoration(
                  labelText: 'Dataset / workbook',
                ),
                items: datasets
                    .map(
                      (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _dataset = v!),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 480 ? double.infinity : 294,
                      child: DropdownButtonFormField<String>(
                        initialValue: _department,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                        ),
                        items: [
                          const DropdownMenuItem(
                            child: Text('All departments'),
                          ),
                          ...?data?.assets
                              .map((a) => a.department)
                              .toSet()
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              ),
                        ],
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _department = v),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth < 480 ? double.infinity : 294,
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Equipment category',
                        ),
                        items: [
                          const DropdownMenuItem(child: Text('All categories')),
                          ...?data?.assets
                              .map((a) => a.equipmentType)
                              .toSet()
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              ),
                        ],
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _category = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Asset status'),
                items: [
                  const DropdownMenuItem(child: Text('All statuses')),
                  ...AssetStatus.values.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  ),
                ],
                onChanged: _loading ? null : (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _borrower,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Borrower name or employee ID',
                  hintText: 'Optional lending filter',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2018),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (range != null) {
                              setState(() => _transactionRange = range);
                            }
                          },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _transactionRange == null
                          ? 'Transaction date range'
                          : '${DateFormat('dd MMM yy').format(_transactionRange!.start)} — ${DateFormat('dd MMM yy').format(_transactionRange!.end)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (range != null) {
                              setState(() => _purchaseRange = range);
                            }
                          },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      _purchaseRange == null
                          ? 'Purchase date range'
                          : '${DateFormat('dd MMM yy').format(_purchaseRange!.start)} — ${DateFormat('dd MMM yy').format(_purchaseRange!.end)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.elevated,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'UI role checks are demonstrative. Production exports must be generated and authorized by the backend, with rate limits and an immutable export audit event.',
                        style: monoStyle(
                          context,
                          size: 9,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: _progress,
                  color: context.colors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  'VALIDATING → BUILDING WORKSHEETS → AUTHORIZING DOWNLOAD',
                  style: monoStyle(
                    context,
                    size: 9,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
              if (_confirmation != null) ...[
                const SizedBox(height: 18),
                _ResultMessage(
                  icon: Icons.check_circle_outline,
                  color: context.colors.accent,
                  text: _confirmation!,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 18),
                _ResultMessage(
                  icon: Icons.error_outline,
                  color: context.colors.danger,
                  text: _error!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _export,
          icon: const Icon(Icons.download),
          label: Text(_loading ? 'GENERATING…' : 'GENERATE & DOWNLOAD'),
        ),
      ],
    );
  }
}

class _ResultMessage extends StatelessWidget {
  const _ResultMessage({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            text,
            style: monoStyle(context, size: 10, color: color),
          ),
        ),
      ],
    ),
  );
}

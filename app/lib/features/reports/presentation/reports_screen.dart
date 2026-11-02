import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../shared/data/workspace_controller.dart';
import '../data/excel_export_service.dart';
import 'export_dialog.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Excel export center',
                  subtitle: 'Typed workbooks, preserved register fields, filtered operational records and authorized financial history.',
                  eyebrow: 'REPORTING / GENUINE .XLSX',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => showExportDialog(context),
                      icon: const Icon(Icons.download),
                      label: const Text('EXPORT TO EXCEL'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                PrecisionPanel(
                  title: 'COMPLETE WORKBOOK STRUCTURE',
                  code: '7 OPERATIONAL SHEETS + SUMMARY',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        [
                              'Inventory Master',
                              'Active Loans',
                              'Lending History',
                              'Damaged Assets',
                              'Disposed Assets',
                              'Depreciation Report',
                              'Authorized Audit History',
                            ]
                            .map(
                              (name) => ActionChip(
                                avatar: const Icon(
                                  Icons.table_rows_outlined,
                                  size: 17,
                                ),
                                label: Text(name),
                                onPressed: () => showExportDialog(context),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 900;
                    final datasets = PrecisionPanel(
                      title: 'CONTROLLED DATASETS',
                      child: Column(
                        children:
                            [
                                  ExportDataset.entireInventory,
                                  ExportDataset.activeLoans,
                                  ExportDataset.lendingHistory,
                                  ExportDataset.overdueEquipment,
                                  ExportDataset.damagedEquipment,
                                  ExportDataset.disposedEquipment,
                                  ExportDataset.valuation,
                                  ExportDataset.audit,
                                ]
                                .map(
                                  (dataset) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    title: Text(dataset.label),
                                    trailing: const Icon(
                                      Icons.download_outlined,
                                    ),
                                    onTap: () => showExportDialog(
                                      context,
                                      preset: dataset,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    );
                    final security = PrecisionPanel(
                      title: 'WORKBOOK CONTROLS',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...[
                            'Professional styled header rows',
                            'Auto-filters and frozen header rows',
                            'Actual date and numeric cell types',
                            'PKR and foreign-value number formats',
                            'Text-preserved IDs and serial numbers',
                            'Formula-injection-safe literal text',
                            'Conditional status and review formatting',
                            'Summary sheet with generation timestamp',
                          ].map(
                            (text) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 16,
                                    color: context.colors.accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(text)),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 26),
                          Text(
                            'PRODUCTION SECURITY BOUNDARY',
                            style: monoStyle(
                              context,
                              size: 9,
                              color: context.colors.warning,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Backend authorization, field-level permissions, export audit logging, rate limits and authorized download endpoints are mandatory. This frontend mock does not replace those controls.',
                          ),
                        ],
                      ),
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          datasets,
                          const SizedBox(height: 16),
                          security,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: datasets),
                        const SizedBox(width: 16),
                        Expanded(child: security),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                PrecisionPanel(
                  title: 'AUTHORIZED EXPORT ACTIVITY',
                  code: 'READ-ONLY',
                  child:
                      data.audit.where((a) => a.category == 'Exports').isEmpty
                      ? const Text(
                          'New mock exports are prepared in this session; production events must be backend-generated.',
                        )
                      : Column(
                          children: data.audit
                              .where((a) => a.category == 'Exports')
                              .map(
                                (a) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.download_done),
                                  title: Text(a.action),
                                  subtitle: Text(
                                    '${a.actor} • ${a.details}\n${DateFormat('dd MMM yyyy HH:mm:ss').format(a.timestamp)}',
                                  ),
                                  trailing: Text(
                                    a.recordId,
                                    style: monoStyle(context, size: 9),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

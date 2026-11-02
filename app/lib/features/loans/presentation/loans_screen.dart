import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../inventory/presentation/asset_profile.dart';
import '../../reports/data/excel_export_service.dart';
import '../../reports/presentation/export_dialog.dart';
import '../data/models/loan_record.dart';
import 'return_dialog.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key, this.initialHistory = false});
  final bool initialHistory;
  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  late bool _history = widget.initialHistory;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) {
        final loans = data.loans
            .where(
              (l) =>
                  (_history
                      ? true
                      : l.status == LoanStatus.active ||
                            l.status == LoanStatus.overdue) &&
                  (_query.isEmpty ||
                      '${l.assetId} ${l.assetName} ${l.borrowerName} ${l.borrowerEmployeeId} ${l.workOrder}'
                          .toLowerCase()
                          .contains(_query.toLowerCase())),
            )
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: _history
                        ? 'Complete lending history'
                        : 'Active equipment loans',
                    subtitle:
                        '${loans.length} transaction records • custody history is never overwritten',
                    eyebrow: 'LENDING / ACCOUNTABILITY',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => showExportDialog(
                          context,
                          preset: _history
                              ? ExportDataset.lendingHistory
                              : ExportDataset.activeLoans,
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('EXPORT AUTHORIZED RECORDS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search asset, borrower, employee ID or work order',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('ACTIVE')),
                          ButtonSegment(value: true, label: Text('HISTORY')),
                        ],
                        selected: {_history},
                        onSelectionChanged: (v) =>
                            setState(() => _history = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loans.isEmpty)
                    const EmptyState(
                      title: 'No matching transactions',
                      message: 'Try another search or switch between active loans and complete history.',
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border.all(color: context.colors.border),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: loans.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: context.colors.border),
                        itemBuilder: (context, index) {
                          final loan = loans[index];
                          final asset = data.assetById(loan.assetId);
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 700;
                                final identity = Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () => showAssetProfile(
                                              context,
                                              loan.assetId,
                                            ),
                                            child: Text(
                                              loan.assetId,
                                              style: monoStyle(
                                                context,
                                                size: 10,
                                                color: context.colors.accent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            loan.assetName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge.loan(loan.status),
                                  ],
                                );
                                final details = Wrap(
                                  spacing: 24,
                                  runSpacing: 12,
                                  children: [
                                    _item(
                                      'BORROWER',
                                      '${loan.borrowerName}\n${loan.borrowerEmployeeId}',
                                    ),
                                    _item('DEPARTMENT', loan.department),
                                    _item('WORK ORDER', loan.workOrder),
                                    _item(
                                      'ISSUE DATE',
                                      DateFormat('dd MMM yyyy • HH:mm')
                                          .format(loan.issueDate),
                                    ),
                                    _item(
                                      'DUE DATE',
                                      DateFormat('dd MMM yyyy • HH:mm')
                                          .format(loan.dueDate),
                                    ),
                                    if (loan.returnDate != null)
                                      _item(
                                        'RETURNED',
                                        DateFormat('dd MMM yyyy • HH:mm')
                                            .format(loan.returnDate!),
                                      ),
                                  ],
                                );
                                final action = !_history && asset != null
                                    ? FilledButton.icon(
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              ReturnDialog(asset: asset),
                                        ),
                                        icon: const Icon(Icons.input),
                                        label: const Text('Receive return'),
                                      )
                                    : null;
                                if (narrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      identity,
                                      const SizedBox(height: 16),
                                      details,
                                      if (action != null) ...[
                                        const SizedBox(height: 14),
                                        action,
                                      ],
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    identity,
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(child: details),
                                        ?action,
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _item(String label, String value) => SizedBox(
    width: 155,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: monoStyle(
            context,
            size: 8,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: monoStyle(context, size: 10)),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../reports/data/excel_export_service.dart';
import '../../reports/presentation/export_dialog.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});
  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String _query = '';
  String? _category;
  DateTimeRange? _range;
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
        final events = data.audit
            .where(
              (a) =>
                  (_query.isEmpty ||
                      '${a.actor} ${a.action} ${a.recordId} ${a.details}'
                          .toLowerCase()
                          .contains(_query.toLowerCase())) &&
                  (_category == null || a.category == _category) &&
                  (_range == null ||
                      (!a.timestamp.isBefore(_range!.start) &&
                          !a.timestamp.isAfter(
                            _range!.end.add(const Duration(days: 1)),
                          ))),
            )
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Immutable audit center',
                    subtitle:
                        '${events.length} events • backend-generated production records • read-only history',
                    eyebrow: 'SECURITY / DATA PROTECTION',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => showExportDialog(
                          context,
                          preset: ExportDataset.audit,
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('EXPORT AUTHORIZED HISTORY'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 430,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search actor, action, record or changes',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            const DropdownMenuItem(
                              child: Text('All categories'),
                            ),
                            ...data.audit
                                .map((a) => a.category)
                                .toSet()
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ),
                                ),
                          ],
                          onChanged: (v) => setState(() => _category = v),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (range != null) setState(() => _range = range);
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _range == null
                              ? 'Date range'
                              : '${DateFormat('dd MMM').format(_range!.start)} — ${DateFormat('dd MMM').format(_range!.end)}',
                        ),
                      ),
                      if (_query.isNotEmpty ||
                          _category != null ||
                          _range != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _query = '';
                            _category = null;
                            _range = null;
                          }),
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (events.isEmpty)
                    const EmptyState(
                      title: 'No audit events match',
                      message: 'Adjust the search, category or date range.',
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
                        itemCount: events.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: context.colors.border),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Icon(
                                      _icon(event.category),
                                      color: event.category == 'Security'
                                          ? context.colors.danger
                                          : context.colors.accent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                            event.action,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            event.category.toUpperCase(),
                                            style: monoStyle(
                                              context,
                                              size: 8,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(event.details),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 18,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                            'ACTOR  ${event.actor}',
                                            style: monoStyle(
                                              context,
                                              size: 9,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'RECORD  ${event.recordId}',
                                            style: monoStyle(
                                              context,
                                              size: 9,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('dd MMM yyyy • HH:mm:ss')
                                                .format(event.timestamp),
                                            style: monoStyle(
                                              context,
                                              size: 9,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Audit events have no edit or delete controls. Production backups must be encrypted, access-restricted and restoration-tested; Excel export is not a backup.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _icon(String category) => switch (category) {
    'Lending' => Icons.handshake_outlined,
    'Approvals' => Icons.verified_user_outlined,
    'Security' => Icons.shield_outlined,
    'Damage' => Icons.report_problem_outlined,
    'Finance' => Icons.account_balance_outlined,
    'Exports' => Icons.download_outlined,
    'Accounts' => Icons.manage_accounts_outlined,
    _ => Icons.fact_check_outlined,
  };
}

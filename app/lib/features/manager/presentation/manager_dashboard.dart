import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/workspace_data.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../../inventory/presentation/asset_profile.dart';
import '../../reports/presentation/export_dialog.dart';

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) => _Dashboard(data: data),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.compactCurrency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 1,
    );
    final stats = [
      (
        'Registered tools',
        '${data.assets.length}',
        'Master asset registry',
        Icons.inventory_2_outlined,
        context.colors.textPrimary,
      ),
      (
        'Available',
        '${data.countStatus(AssetStatus.available)}',
        'Ready for handover',
        Icons.check_circle_outline,
        context.colors.accent,
      ),
      (
        'Checked out',
        '${data.countStatus(AssetStatus.checkedOut)}',
        'In mechanic custody',
        Icons.output_outlined,
        context.colors.info,
      ),
      (
        'Overdue',
        '${data.countStatus(AssetStatus.overdue)}',
        'Return deadline breached',
        Icons.schedule_outlined,
        context.colors.danger,
      ),
      (
        'Missing',
        '${data.countStatus(AssetStatus.missing)}',
        'Search required',
        Icons.person_search_outlined,
        context.colors.danger,
      ),
      (
        'Damaged',
        '${data.damagedCount}',
        'Damage + quarantine',
        Icons.report_problem_outlined,
        context.colors.warning,
      ),
      (
        'Disposed',
        '${data.countStatus(AssetStatus.retired)}',
        'Preserved in archive',
        Icons.archive_outlined,
        context.colors.textSecondary,
      ),
      (
        'Pending approvals',
        '${data.pendingApprovals}',
        'Authorization queue',
        Icons.verified_user_outlined,
        context.colors.warning,
      ),
      (
        'Purchase value',
        money.format(data.totalPurchaseValue),
        'Historical acquisition',
        Icons.payments_outlined,
        context.colors.textPrimary,
      ),
      (
        'Net book value',
        money.format(data.netBookValue),
        'Valuation date: today',
        Icons.account_balance_outlined,
        context.colors.accent,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Operations command center',
                subtitle: 'Live inventory accountability, lending exposure and asset valuation.',
                eyebrow: 'MANAGER / PRODUCT SUPPORT',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/manager/scan'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan asset'),
                  ),
                  FilledButton.icon(
                    onPressed: () => showExportDialog(context),
                    icon: const Icon(Icons.download),
                    label: const Text('EXPORT TO EXCEL'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1450
                      ? 5
                      : constraints.maxWidth > 950
                      ? 4
                      : constraints.maxWidth > 560
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: stats
                        .map(
                          (s) => SizedBox(
                            width: width,
                            child: MetricTile(
                              label: s.$1,
                              value: s.$2,
                              detail: s.$3,
                              icon: s.$4,
                              tone: s.$5,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 1050;
                  final operations = PrecisionPanel(
                    title: 'LIVE OPERATIONS / ACTIVE LOANS',
                    code: '${data.activeLoans.length} RECORDS',
                    padding: EdgeInsets.zero,
                    child: _LoanFeed(data: data),
                  );
                  final attention = _AttentionPanel(data: data);
                  if (!wide) {
                    return Column(
                      children: [
                        operations,
                        const SizedBox(height: 16),
                        attention,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: operations),
                      const SizedBox(width: 16),
                      Expanded(child: attention),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _EquipmentRack(data: data),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 1100;
                  final charts = [
                    SizedBox(height: 320, child: _BorrowingChart(data: data)),
                    SizedBox(
                      height: 320,
                      child: _AvailabilityChart(data: data),
                    ),
                    SizedBox(height: 320, child: _DepartmentChart(data: data)),
                  ];
                  if (!wide) {
                    return Column(
                      children: charts
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: c,
                            ),
                          )
                          .toList(),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: charts[0]),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: charts[1]),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: charts[2]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanFeed extends StatelessWidget {
  const _LoanFeed({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final loans = data.activeLoans;
    if (loans.isEmpty) {
      return const EmptyState(
        title: 'No active loans',
        message: 'All equipment is currently accounted for in storage or an archive.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 920),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('EQUIPMENT')),
            DataColumn(label: Text('BORROWER')),
            DataColumn(label: Text('DEPARTMENT')),
            DataColumn(label: Text('ISSUED')),
            DataColumn(label: Text('DUE')),
            DataColumn(label: Text('STATUS')),
          ],
          rows: loans
              .map(
                (loan) => DataRow(
                  onSelectChanged: (_) =>
                      showAssetProfile(context, loan.assetId),
                  cells: [
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.assetId,
                            style: monoStyle(
                              context,
                              size: 11,
                              color: context.colors.accent,
                            ),
                          ),
                          Text(
                            loan.assetName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loan.borrowerName),
                          Text(
                            loan.borrowerEmployeeId,
                            style: monoStyle(
                              context,
                              size: 9,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(loan.department)),
                    DataCell(
                      Text(
                        DateFormat('dd MMM\nHH:mm').format(loan.issueDate),
                        style: monoStyle(context, size: 10),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('dd MMM\nHH:mm').format(loan.dueDate),
                        style: monoStyle(context, size: 10),
                      ),
                    ),
                    DataCell(StatusBadge.loan(loan.status, compact: true)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color, String?)>[
      ...data.assets
          .where((a) => a.status == AssetStatus.overdue)
          .map(
            (a) => (
              Icons.schedule,
              'Overdue return',
              '${a.id} • ${a.currentBorrower}',
              context.colors.danger,
              a.id,
            ),
          ),
      ...data.assets
          .where((a) => a.status == AssetStatus.missing)
          .map(
            (a) => (
              Icons.person_search,
              'Missing asset',
              '${a.id} • ${a.lyingAt}',
              context.colors.danger,
              a.id,
            ),
          ),
      ...data.approvals
          .where((a) => a.status.name == 'pending')
          .map(
            (a) => (
              Icons.verified_user,
              'High-value authorization',
              '${a.assetId} • PKR ${NumberFormat.compact().format(a.amountPkr)}',
              context.colors.warning,
              a.assetId,
            ),
          ),
      ...data.assets
          .where(
            (a) =>
                a.status == AssetStatus.damaged ||
                a.status == AssetStatus.quarantined,
          )
          .map(
            (a) => (
              Icons.report_problem,
              'Damaged / quarantined',
              '${a.id} • ${a.condition}',
              context.colors.warning,
              a.id,
            ),
          ),
    ];
    return PrecisionPanel(
      title: 'CRITICAL ATTENTION',
      code: '${items.length} FLAGS',
      padding: const EdgeInsets.all(8),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No critical flags. Operations are within configured rules.',
              ),
            )
          : Column(
              children: items
                  .take(6)
                  .map(
                    (item) => ListTile(
                      onTap: item.$5 == null
                          ? null
                          : () => showAssetProfile(context, item.$5!),
                      leading: Icon(item.$1, color: item.$4),
                      title: Text(
                        item.$2,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        item.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _EquipmentRack extends StatelessWidget {
  const _EquipmentRack({required this.data});
  final WorkspaceData data;
  Color _color(BuildContext context, AssetStatus status) => switch (status) {
    AssetStatus.available => context.colors.accent,
    AssetStatus.checkedOut => context.colors.info,
    AssetStatus.overdue ||
    AssetStatus.missing ||
    AssetStatus.damaged ||
    AssetStatus.quarantined => context.colors.danger,
    AssetStatus.underMaintenance ||
    AssetStatus.retired => context.colors.warning,
  };
  @override
  Widget build(BuildContext context) => PrecisionPanel(
    title: 'VISUAL EQUIPMENT RACK',
    code: 'SELECT AN ASSET TO INSPECT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.assets
              .map(
                (asset) => Tooltip(
                  message: '${asset.description}\n${asset.status.label}',
                  child: InkWell(
                    onTap: () => showAssetProfile(context, asset.id),
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 72,
                      height: 58,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _color(
                          context,
                          asset.status,
                        ).withValues(alpha: .10),
                        border: Border.all(
                          color: _color(
                            context,
                            asset.status,
                          ).withValues(alpha: .75),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 14,
                            height: 3,
                            color: _color(context, asset.status),
                          ),
                          const Spacer(),
                          Text(
                            asset.id.replaceAll('TL-', ''),
                            maxLines: 2,
                            style: monoStyle(
                              context,
                              size: 8,
                              color: _color(context, asset.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children:
              [
                    AssetStatus.available,
                    AssetStatus.checkedOut,
                    AssetStatus.overdue,
                    AssetStatus.damaged,
                    AssetStatus.underMaintenance,
                  ]
                  .map(
                    (s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          color: _color(context, s),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: monoStyle(
                            context,
                            size: 8,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
  );
}

class _BorrowingChart extends StatelessWidget {
  const _BorrowingChart({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final values = [
      3.0,
      5.0,
      2.0,
      6.0,
      4.0,
      7.0,
      data.activeLoans.length.toDouble(),
    ];
    return PrecisionPanel(
      title: 'BORROWING ACTIVITY',
      code: 'LAST 7 DAYS',
      child: SizedBox(
        height: 230,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: context.colors.grid, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: monoStyle(
                      context,
                      size: 9,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text(
                    ['SAT', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'][v
                        .toInt()
                        .clamp(0, 6)],
                    style: monoStyle(
                      context,
                      size: 9,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            barGroups: values.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2,
                        color: e.$1 == 6
                            ? context.colors.accent
                            : context.colors.info,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
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

class _AvailabilityChart extends StatelessWidget {
  const _AvailabilityChart({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final available = data.countStatus(AssetStatus.available).toDouble();
    final issued = data.activeLoans.length.toDouble();
    final other = (data.assets.length - available - issued)
        .clamp(0, data.assets.length)
        .toDouble();
    return PrecisionPanel(
      title: 'EQUIPMENT AVAILABILITY',
      code: 'CURRENT STATE',
      child: SizedBox(
        height: 210,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                centerSpaceRadius: 55,
                sectionsSpace: 3,
                sections: [
                  PieChartSectionData(
                    value: available,
                    color: context.colors.accent,
                    radius: 26,
                    title: '${available.toInt()}',
                    titleStyle: monoStyle(
                      context,
                      size: 11,
                      color: context.colors.background,
                    ),
                  ),
                  PieChartSectionData(
                    value: issued,
                    color: context.colors.info,
                    radius: 26,
                    title: '${issued.toInt()}',
                    titleStyle: monoStyle(
                      context,
                      size: 11,
                      color: context.colors.background,
                    ),
                  ),
                  PieChartSectionData(
                    value: other,
                    color: context.colors.warning,
                    radius: 26,
                    title: '${other.toInt()}',
                    titleStyle: monoStyle(
                      context,
                      size: 11,
                      color: context.colors.background,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.assets.length}',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontFamily: AppTheme.monoFont),
                ),
                Text(
                  'ASSETS',
                  style: monoStyle(
                    context,
                    size: 9,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              child: Wrap(
                spacing: 12,
                children:
                    [
                          ('Available', context.colors.accent),
                          ('Issued', context.colors.info),
                          ('Other', context.colors.warning),
                        ]
                        .map(
                          (e) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 7, color: e.$2),
                              const SizedBox(width: 5),
                              Text(
                                e.$1,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentChart extends StatelessWidget {
  const _DepartmentChart({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final departments = data.assets
        .map((a) => a.department)
        .toSet()
        .take(5)
        .toList();
    final values = departments
        .map(
          (d) => data.assets.where((a) => a.department == d).length.toDouble(),
        )
        .toList();
    return PrecisionPanel(
      title: 'DEPARTMENT USAGE',
      code: 'REGISTERED ASSETS',
      child: SizedBox(
        height: 230,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  getTitlesWidget: (v, _) {
                    final index = v.toInt();
                    if (index < 0 || index >= departments.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 58,
                        child: Text(
                          departments[index].split(' ').first.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: monoStyle(
                            context,
                            size: 8,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: values.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2,
                        color: context.colors.accent,
                        width: 24,
                        borderRadius: BorderRadius.zero,
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            e.$2 * .55,
                            context.colors.info,
                          ),
                        ],
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

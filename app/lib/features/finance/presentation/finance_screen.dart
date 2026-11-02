import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../inventory/presentation/asset_profile.dart';
import '../../reports/data/excel_export_service.dart';
import '../../reports/presentation/export_dialog.dart';
import '../data/depreciation_calculator.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});
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
            constraints: const BoxConstraints(maxWidth: 1560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Finance & depreciation',
                  subtitle: 'Straight-line policy calculations with immutable historical spreadsheet values.',
                  eyebrow: 'MANAGER / ASSET VALUATION',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => showExportDialog(
                        context,
                        preset: ExportDataset.valuation,
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('EXPORT VALUATION'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FinanceMetrics(data: data),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 1050;
                    final trend = SizedBox(
                      height: 340,
                      child: _AnnualTrend(data: data),
                    );
                    final calculator = const DepreciationPanel();
                    if (!wide) {
                      return Column(
                        children: [
                          trend,
                          const SizedBox(height: 16),
                          calculator,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: trend),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: calculator),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _DepartmentValues(data: data),
                const SizedBox(height: 16),
                _ValuationReview(data: data),
                const SizedBox(height: 16),
                PrecisionPanel(
                  title: 'DISPOSAL FINANCIAL HISTORY',
                  code: '${data.disposals.length} RECORDS',
                  child: data.disposals.isEmpty
                      ? const Text('No disposal history.')
                      : Column(
                          children: data.disposals
                              .map(
                                (d) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(d.assetId),
                                  subtitle: Text(
                                    '${d.reason}\n${DateFormat('dd MMM yyyy').format(d.disposalDate)} • ${d.authorizedBy}',
                                  ),
                                  trailing: Text(
                                    'NBV ${NumberFormat.compactCurrency(symbol: 'PKR ').format(d.netBookValueAtDisposalPkr)}\nProceeds ${NumberFormat.compactCurrency(symbol: 'PKR ').format(d.proceedsPkr)}',
                                    style: monoStyle(context, size: 10),
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

class _FinanceMetrics extends StatelessWidget {
  const _FinanceMetrics({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.compactCurrency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 1,
    );
    final avgAge = data.assets.isEmpty
        ? 0
        : data.assets.map((a) => a.daysSincePurchase).reduce((a, b) => a + b) ~/
              data.assets.length;
    final values = [
      (
        'Original purchase value',
        money.format(data.totalPurchaseValue),
        Icons.payments_outlined,
      ),
      (
        'Total depreciation',
        money.format(data.totalDepreciation),
        Icons.trending_down,
      ),
      (
        'Remaining book value',
        money.format(data.netBookValue),
        Icons.account_balance_wallet_outlined,
      ),
      (
        'Average asset age',
        '${(avgAge / 365).toStringAsFixed(1)} years',
        Icons.schedule_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 480
            ? 2
            : 1;
        final width = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: values
              .map(
                (v) => SizedBox(
                  width: width,
                  child: MetricTile(
                    label: v.$1,
                    value: v.$2,
                    icon: v.$3,
                    detail: 'Current valuation policy',
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AnnualTrend extends StatelessWidget {
  const _AnnualTrend({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final purchase = data.totalPurchaseValue;
    final residual = data.assets.fold(
      0.0,
      (sum, a) => sum + a.residualValuePkr,
    );
    final annual = data.assets.fold(
      0.0,
      (sum, a) => sum + a.dailyDepreciation * 365,
    );
    return PrecisionPanel(
      title: 'ANNUAL DEPRECIATION TREND',
      code: 'POLICY PROJECTION',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: context.colors.grid),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 55,
                  getTitlesWidget: (v, _) => Text(
                    NumberFormat.compact().format(v),
                    style: monoStyle(
                      context,
                      size: 8,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text(
                    'Y${v.toInt() + 1}',
                    style: monoStyle(
                      context,
                      size: 9,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: false,
                color: context.colors.accent,
                barWidth: 2,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: context.colors.accent.withValues(alpha: .07),
                ),
                spots: List.generate(
                  6,
                  (i) => FlSpot(
                    i.toDouble(),
                    (purchase - residual - annual * i).clamp(0, purchase),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepartmentValues extends StatelessWidget {
  const _DepartmentValues({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final departments = data.assets.map((a) => a.department).toSet().toList();
    return PrecisionPanel(
      title: 'DEPARTMENT-WISE ASSET VALUES',
      code: 'NET BOOK VALUE',
      child: Column(
        children: departments.map((department) {
          final assets = data.assets
              .where((a) => a.department == department)
              .toList();
          final value = assets.fold(0.0, (sum, a) => sum + a.netBookValue);
          final ratio = data.netBookValue == 0
              ? 0.0
              : value / data.netBookValue;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Text(
                    department,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    color: context.colors.accent,
                    backgroundColor: context.colors.elevated,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text(
                    NumberFormat.compactCurrency(symbol: 'PKR ').format(value),
                    textAlign: TextAlign.right,
                    style: monoStyle(context, size: 10),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ValuationReview extends StatelessWidget {
  const _ValuationReview({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) => PrecisionPanel(
    title: 'SOURCE CALCULATION REVIEW',
    code: '${data.assets.where((a) => a.financialReviewRequired).length} FLAGS',
    padding: EdgeInsets.zero,
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.assets.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.border),
      itemBuilder: (context, index) {
        final asset = data.assets[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          onTap: () => showAssetProfile(context, asset.id),
          title: Text(asset.description),
          subtitle: Text(
            '${asset.id} • Historical ${NumberFormat.compactCurrency(symbol: 'PKR ').format(asset.historicalAccumulatedDepreciationPkr)} • Calculated ${NumberFormat.compactCurrency(symbol: 'PKR ').format(asset.accumulatedDepreciation)}',
          ),
          trailing: asset.financialReviewRequired
              ? StatusBadge(label: 'REVIEW', tone: StatusTone.warning)
              : StatusBadge(label: 'POLICY OK', tone: StatusTone.positive),
        );
      },
    ),
  );
}

class DepreciationPanel extends StatefulWidget {
  const DepreciationPanel({super.key});
  @override
  State<DepreciationPanel> createState() => _DepreciationPanelState();
}

class _DepreciationPanelState extends State<DepreciationPanel> {
  final _cost = TextEditingController(text: '500000');
  final _residual = TextEditingController(text: '25000');
  final _life = TextEditingController(text: '5');
  DateTime _purchase = DateTime(DateTime.now().year - 2);
  DateTime _valuation = DateTime.now();
  DepreciationResult? _result;
  String? _error;
  @override
  void dispose() {
    _cost.dispose();
    _residual.dispose();
    _life.dispose();
    super.dispose();
  }

  void _calculate() {
    try {
      setState(() {
        _result = const DepreciationCalculator().straightLine(
          purchaseCost: double.parse(_cost.text),
          residualValue: double.parse(_residual.text),
          usefulLifeYears: int.parse(_life.text),
          purchaseDate: _purchase,
          valuationDate: _valuation,
        );
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 2,
    );
    return PrecisionPanel(
      title: 'STRAIGHT-LINE CALCULATOR',
      code: 'CONFIGURABLE POLICY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _field(_cost, 'Purchase cost'),
              _field(_residual, 'Residual value'),
              _field(_life, 'Useful life (years)'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _date(
                'Purchase: ${DateFormat('dd MMM yy').format(_purchase)}',
                () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _purchase,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _purchase = d);
                },
              ),
              _date(
                'Valuation: ${DateFormat('dd MMM yy').format(_valuation)}',
                () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _valuation,
                    firstDate: _purchase,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _valuation = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('CALCULATE'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.colors.danger, fontSize: 12),
            ),
          ],
          if (_result != null) ...[
            const Divider(height: 26),
            KeyValueRow(
              label: 'Age days',
              value: '${_result!.ageDays}',
              mono: true,
            ),
            KeyValueRow(
              label: 'Depreciable cost',
              value: money.format(_result!.depreciableCost),
              mono: true,
            ),
            KeyValueRow(
              label: 'Daily depreciation',
              value: money.format(_result!.daily),
              mono: true,
            ),
            KeyValueRow(
              label: 'Accumulated (capped)',
              value: money.format(_result!.accumulated),
              mono: true,
            ),
            KeyValueRow(
              label: 'Net book value',
              value: money.format(_result!.netBookValue),
              mono: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => SizedBox(
    width: 135,
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );
  Widget _date(String text, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.date_range, size: 17),
    label: Text(text),
  );
}

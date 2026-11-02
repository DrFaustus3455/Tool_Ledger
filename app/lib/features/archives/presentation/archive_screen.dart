import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/asset_photo.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/workspace_data.dart';
import '../../inventory/presentation/asset_profile.dart';
import '../../reports/data/excel_export_service.dart';
import '../../reports/presentation/export_dialog.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});
  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  var _disposed = false;
  @override
  Widget build(BuildContext context) {
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
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Damaged & disposed archives',
                  subtitle: 'Separate operational registers backed by a permanent authoritative asset history.',
                  eyebrow: 'ARCHIVE / RECORDS NEVER ERASED',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => showExportDialog(
                        context,
                        preset: _disposed
                            ? ExportDataset.disposedEquipment
                            : ExportDataset.damagedEquipment,
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('EXPORT TO EXCEL'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.report_problem_outlined),
                      label: Text('DAMAGED REGISTER (${data.damages.length})'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(
                        'DISPOSED REGISTER (${data.disposals.length})',
                      ),
                    ),
                  ],
                  selected: {_disposed},
                  onSelectionChanged: (v) =>
                      setState(() => _disposed = v.first),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _disposed
                      ? _DisposedRegister(
                          key: const ValueKey('disposed'),
                          data: data,
                        )
                      : _DamagedRegister(
                          key: const ValueKey('damaged'),
                          data: data,
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

class _DamagedRegister extends StatelessWidget {
  const _DamagedRegister({super.key, required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    if (data.damages.isEmpty) {
      return const EmptyState(
        title: 'Damaged register is empty',
        message: 'Damage and quarantine reports will be preserved here.',
      );
    }
    return Column(
      children: data.damages.map((damage) {
        final asset = data.assetById(damage.assetId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: PrecisionPanel(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                final photo = InkWell(
                  onTap: () => showAssetProfile(context, damage.assetId),
                  child: AssetPhoto(
                    url: asset?.photoUrl,
                    label: damage.assetId,
                    width: narrow ? double.infinity : 230,
                    height: 240,
                  ),
                );
                final content = Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              damage.assetId,
                              style: monoStyle(
                                context,
                                size: 12,
                                color: context.colors.danger,
                              ),
                            ),
                          ),
                          Text(
                            damage.repairStatus.toUpperCase(),
                            style: monoStyle(
                              context,
                              size: 9,
                              color: context.colors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        asset?.description ?? damage.assetId,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(damage.description),
                      const SizedBox(height: 12),
                      Text(
                        'Reported by ${damage.reportedBy} • ${DateFormat('dd MMM yyyy').format(damage.damageDate)} • ${damage.evidenceCount} evidence photographs',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 26),
                      Wrap(
                        spacing: 26,
                        runSpacing: 12,
                        children: [
                          _value(
                            context,
                            'ORIGINAL COST',
                            money.format(damage.originalCostPkr),
                          ),
                          _value(
                            context,
                            'ACCUMULATED DEPRECIATION',
                            money.format(damage.accumulatedDepreciationPkr),
                          ),
                          _value(
                            context,
                            'NET BOOK VALUE',
                            money.format(damage.netBookValuePkr),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                if (narrow) return Column(children: [photo, content]);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    photo,
                    Expanded(child: content),
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _value(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: monoStyle(context, size: 8, color: context.colors.textSecondary),
      ),
      const SizedBox(height: 5),
      Text(value, style: monoStyle(context, size: 12)),
    ],
  );
}

class _DisposedRegister extends StatelessWidget {
  const _DisposedRegister({super.key, required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    if (data.disposals.isEmpty) {
      return const EmptyState(
        title: 'Disposed register is empty',
        message:
            'Authorized disposal records will be preserved here permanently.',
      );
    }
    return Column(
      children: data.disposals
          .map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PrecisionPanel(
                title: 'DISPOSAL AUTHORIZATION',
                code: d.assetId,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            data.assetById(d.assetId)?.description ?? d.assetId,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => showAssetProfile(context, d.assetId),
                          child: const Text('Inspect authoritative history'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(d.reason),
                    const SizedBox(height: 12),
                    Text(
                      '${d.purchaseSummary}\nDisposed ${DateFormat('dd MMM yyyy').format(d.disposalDate)} • ${d.transactionCount} historical transactions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(height: 26),
                    Wrap(
                      spacing: 24,
                      runSpacing: 14,
                      children: [
                        _v(
                          context,
                          'ORIGINAL COST',
                          money.format(d.originalCostPkr),
                        ),
                        _v(
                          context,
                          'DEPRECIATION',
                          money.format(d.accumulatedDepreciationPkr),
                        ),
                        _v(
                          context,
                          'NBV AT DISPOSAL',
                          money.format(d.netBookValueAtDisposalPkr),
                        ),
                        _v(
                          context,
                          'SALVAGE PROCEEDS',
                          money.format(d.proceedsPkr),
                        ),
                        _v(context, 'AUTHORIZED BY', d.authorizedBy),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _v(BuildContext context, String label, String value) => SizedBox(
    width: 190,
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
        const SizedBox(height: 5),
        Text(value, style: monoStyle(context, size: 11)),
      ],
    ),
  );
}

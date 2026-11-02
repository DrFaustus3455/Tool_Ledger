import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/workspace_data.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../../inventory/presentation/asset_profile.dart';

class LenderWorkspace extends ConsumerWidget {
  const LenderWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) {
        final user = ref.watch(sessionProvider).user!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Lending workspace',
                    subtitle:
                        '${user.displayName} • ${user.employeeId} • Tool store shift active',
                    eyebrow: 'LENDER / FAST OPERATIONS',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/lender/loans'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text('${data.activeLoans.length} active loans'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 900;
                      final scan = _ScanAction(
                        onTap: () => context.go('/lender/scan'),
                      );
                      final stats = _ShiftStats(data: data);
                      if (!wide) {
                        return Column(
                          children: [scan, const SizedBox(height: 16), stats],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: scan),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: stats),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'QUICK OPERATIONS',
                    style: monoStyle(
                      context,
                      size: 10,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions =
                          <(IconData, String, String, VoidCallback)>[
                            (
                              Icons.output,
                              'Issue Tool',
                              'Verify, borrower, handover',
                              () => context.go('/lender/scan?mode=issue'),
                            ),
                            (
                              Icons.input,
                              'Receive Return',
                              'Inspect and close active loan',
                              () => context.go('/lender/scan?mode=return'),
                            ),
                            (
                              Icons.search,
                              'Search Inventory',
                              'Operational asset records',
                              () => context.go('/lender/inventory'),
                            ),
                            (
                              Icons.receipt_long_outlined,
                              'Active Loans',
                              'Borrower and due dates',
                              () => context.go('/lender/loans'),
                            ),
                            (
                              Icons.verified_user_outlined,
                              'Approval Requests',
                              'Track and confirm handover',
                              () => context.go('/lender/approvals'),
                            ),
                            (
                              Icons.report_problem_outlined,
                              'Report Damage',
                              'Evidence and quarantine',
                              () => context.go('/lender/scan?mode=damage'),
                            ),
                            (
                              Icons.history,
                              'Recent Transactions',
                              'Complete lending history',
                              () => context.go('/lender/loans?history=true'),
                            ),
                          ];
                      final columns = constraints.maxWidth > 1000
                          ? 4
                          : constraints.maxWidth > 600
                          ? 3
                          : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: actions
                            .map(
                              (a) => SizedBox(
                                width: width,
                                height: 118,
                                child: Material(
                                  color: context.colors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                    side: BorderSide(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: a.$4,
                                    borderRadius: BorderRadius.circular(7),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            a.$1,
                                            color: context.colors.accent,
                                            size: 23,
                                          ),
                                          const Spacer(),
                                          Text(
                                            a.$2,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            a.$3,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _RecentTransactions(data: data),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Scan equipment QR code',
    child: Material(
      color: context.colors.accent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 210,
          padding: const EdgeInsets.all(26),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -24,
                child: Icon(
                  Icons.qr_code_2,
                  size: 180,
                  color: context.colors.background.withValues(alpha: .10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 38,
                    color: context.colors.background,
                  ),
                  const Spacer(),
                  Text(
                    'SCAN EQUIPMENT',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: context.colors.background,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Camera • manual asset ID • USB scanner',
                    style: monoStyle(
                      context,
                      size: 10,
                      color: context.colors.background,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShiftStats extends StatelessWidget {
  const _ShiftStats({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) => Container(
    height: 210,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, color: context.colors.accent),
            const SizedBox(width: 8),
            Text(
              'OPERATIONAL STATUS',
              style: monoStyle(
                context,
                size: 10,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        _row(
          context,
          'Available to issue',
          '${data.countStatus(AssetStatus.available)}',
        ),
        _row(context, 'Awaiting return', '${data.activeLoans.length}'),
        _row(context, 'Pending authorization', '${data.pendingApprovals}'),
        const Spacer(),
        Text(
          'Recheck is required before every handover.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: monoStyle(context, size: 18, color: context.colors.accent),
        ),
      ],
    ),
  );
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.data});
  final WorkspaceData data;
  @override
  Widget build(BuildContext context) => PrecisionPanel(
    title: 'RECENT TRANSACTIONS',
    code: 'COMPLETE HISTORY PRESERVED',
    padding: EdgeInsets.zero,
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.loans.take(5).length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.border),
      itemBuilder: (context, index) {
        final loan = data.loans[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          onTap: () => showAssetProfile(context, loan.assetId),
          leading: Icon(
            loan.returnDate == null ? Icons.output : Icons.input,
            color: loan.returnDate == null
                ? context.colors.info
                : context.colors.accent,
          ),
          title: Text(loan.assetName),
          subtitle: Text(
            '${loan.assetId} • ${loan.borrowerName} • ${DateFormat('dd MMM, HH:mm').format(loan.issueDate)}',
          ),
          trailing: StatusBadge.loan(loan.status),
        );
      },
    ),
  );
}

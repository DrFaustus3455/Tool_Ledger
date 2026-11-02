import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/precision_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/data/workspace_controller.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/workspace_data.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/asset_profile.dart';
import '../data/models/approval_record.dart';

class ApprovalCenter extends ConsumerStatefulWidget {
  const ApprovalCenter({super.key});
  @override
  ConsumerState<ApprovalCenter> createState() => _ApprovalCenterState();
}

class _ApprovalCenterState extends ConsumerState<ApprovalCenter> {
  ApprovalStatus _filter = ApprovalStatus.pending;
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceProvider);
    final user = ref.watch(sessionProvider).user!;
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.read(workspaceProvider.notifier).refresh(),
      ),
      data: (data) {
        final authorized = user.role == UserRole.manager
            ? data.approvals
            : data.approvals
                  .where((a) => a.requestedByEmployeeId == user.employeeId)
                  .toList();
        final visible = authorized.where((a) => a.status == _filter).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: user.role == UserRole.manager
                        ? 'Manager approval center'
                        : 'My approval requests',
                    subtitle: user.role == UserRole.manager
                        ? 'Explicit authorization with decision notes, timestamps and sensitive-action verification.'
                        : 'Track authorization and complete handover only after approval.',
                    eyebrow: 'AUTHORIZATION / NO SILENT APPROVALS',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ApprovalStatus.values.map((status) {
                      final count = authorized
                          .where((a) => a.status == status)
                          .length;
                      return ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: _filter == status
                              ? context.colors.accent
                              : context.colors.elevated,
                          child: Text(
                            '$count',
                            style: monoStyle(
                              context,
                              size: 9,
                              color: _filter == status
                                  ? context.colors.background
                                  : context.colors.textPrimary,
                            ),
                          ),
                        ),
                        label: Text(switch (status) {
                          ApprovalStatus.pending => 'PENDING',
                          ApprovalStatus.approved => 'APPROVED',
                          ApprovalStatus.rejected => 'REJECTED',
                          ApprovalStatus.needsClarification =>
                            'NEEDS CLARIFICATION',
                        }),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  if (visible.isEmpty)
                    EmptyState(
                      title: 'No ${_filter.name} requests',
                      message: 'Requests in this authorization state will appear here.',
                    )
                  else
                    ...visible.map(
                      (approval) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ApprovalCard(
                          approval: approval,
                          user: user,
                          data: data,
                        ),
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
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({
    required this.approval,
    required this.user,
    required this.data,
  });
  final ApprovalRecord approval;
  final AppUser user;
  final WorkspaceData data;

  Future<void> _decision(
    BuildContext context,
    WidgetRef ref,
    ApprovalStatus decision,
  ) async {
    final note = TextEditingController();
    final mfa = TextEditingController();
    final sensitive =
        approval.amountPkr >= data.settings.approvalThresholdPkr ||
        approval.type == ApprovalType.disposal;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${decision == ApprovalStatus.approved
              ? 'Approve'
              : decision == ApprovalStatus.rejected
              ? 'Reject'
              : 'Request clarification'} — ${approval.assetId}',
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(approval.reason),
                  const SizedBox(height: 10),
                  Text(
                    '${approval.typeLabel} • PKR ${NumberFormat('#,##0').format(approval.amountPkr)}',
                    style: monoStyle(
                      context,
                      size: 10,
                      color: context.colors.warning,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: note,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: decision == ApprovalStatus.needsClarification
                          ? 'Clarification required'
                          : 'Decision note (required)',
                    ),
                    validator: (v) => v == null || v.trim().length < 4
                        ? 'Enter a meaningful decision note'
                        : null,
                  ),
                  if (sensitive) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: mfa,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Manager MFA verification',
                        hintText: 'Demo code: 246810',
                      ),
                      validator: (v) => v != '246810'
                          ? 'Enter the 6-digit demonstration MFA code'
                          : null,
                    ),
                    const Text(
                      'Production verification must use server-managed MFA or reauthentication; this demo code is not security.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: decision == ApprovalStatus.rejected
                ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
                : null,
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(
              decision == ApprovalStatus.approved
                  ? 'CONFIRM APPROVAL'
                  : decision == ApprovalStatus.rejected
                  ? 'CONFIRM REJECTION'
                  : 'SEND CLARIFICATION',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(workspaceProvider.notifier)
          .decideApproval(approval.id, decision, note.text, user);
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Decision recorded with timestamp and audit event.',
        );
      }
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, '$e', error: true);
    } finally {
      note.dispose();
      mfa.dispose();
    }
  }

  Future<void> _handover(BuildContext context, WidgetRef ref) async {
    var verified = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Final handover authorization recheck'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${approval.assetId} • ${approval.assetName}'),
              const SizedBox(height: 12),
              Text(approval.borrowerDetails ?? ''),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: verified,
                onChanged: (v) => setState(() => verified = v ?? false),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'The tool is still available, serviceable, and physically ready for the named borrower.',
                ),
              ),
              const Text(
                'The repository rechecks approval and availability again before creating the loan.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: verified ? () => Navigator.pop(context, true) : null,
              child: const Text('CONFIRM PHYSICAL HANDOVER'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(workspaceProvider.notifier)
          .completeHandover(approval.id, user);
      if (context.mounted) {
        showAppSnackBar(
          context,
          '${approval.assetId} checked out after final authorization recheck.',
        );
      }
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrecisionPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.typeLabel,
                    style: monoStyle(
                      context,
                      size: 9,
                      color: context.colors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    approval.assetName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            StatusBadge.approval(approval.status),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Text(approval.id, style: monoStyle(context, size: 10)),
            if (data.assetById(approval.assetId) != null)
              InkWell(
                onTap: () => showAssetProfile(context, approval.assetId),
                child: Text(
                  approval.assetId,
                  style: monoStyle(
                    context,
                    size: 10,
                    color: context.colors.accent,
                  ),
                ),
              )
            else
              Text(approval.assetId, style: monoStyle(context, size: 10)),
            Text(
              'PKR ${NumberFormat('#,##0').format(approval.amountPkr)}',
              style: monoStyle(context, size: 10),
            ),
            Text(
              DateFormat('dd MMM yyyy • HH:mm').format(approval.requestedAt),
              style: monoStyle(
                context,
                size: 10,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const Divider(height: 26),
        Text(approval.reason, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 10),
        Text(
          'Requested by ${approval.requestedBy} • ${approval.requestedByEmployeeId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (approval.borrowerDetails != null) ...[
          const SizedBox(height: 6),
          Text(
            approval.borrowerDetails!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (approval.evidenceCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${approval.evidenceCount} supporting evidence file(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (approval.decisionNote != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: context.colors.elevated,
            child: Text(
              '${approval.decidedBy} • ${approval.decisionNote}\n${approval.decidedAt == null ? '' : DateFormat('dd MMM yyyy HH:mm').format(approval.decidedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        if (user.role == UserRole.manager &&
            approval.status == ApprovalStatus.pending) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _decision(context, ref, ApprovalStatus.approved),
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _decision(context, ref, ApprovalStatus.rejected),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
              TextButton.icon(
                onPressed: () =>
                    _decision(context, ref, ApprovalStatus.needsClarification),
                icon: const Icon(Icons.help_outline),
                label: const Text('Request clarification'),
              ),
            ],
          ),
        ],
        if (user.role == UserRole.lender &&
            approval.status == ApprovalStatus.approved &&
            approval.checkoutDraft != null &&
            !data.loans.any((l) => l.approvalId == approval.id)) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _handover(context, ref),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('CONFIRM PHYSICAL HANDOVER'),
          ),
        ],
      ],
    ),
  );
}

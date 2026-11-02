import 'package:flutter/material.dart';

import '../../features/approvals/data/models/approval_record.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/loans/data/models/loan_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.compact = false,
  }) : status = null,
       approval = null,
       loan = null;
  const StatusBadge.asset(this.status, {super.key, this.compact = false})
    : label = '',
      approval = null,
      loan = null,
      tone = StatusTone.neutral;
  const StatusBadge.approval(this.approval, {super.key, this.compact = false})
    : label = '',
      status = null,
      loan = null,
      tone = StatusTone.neutral;
  const StatusBadge.loan(this.loan, {super.key, this.compact = false})
    : label = '',
      status = null,
      approval = null,
      tone = StatusTone.neutral;
  final String label;
  final AssetStatus? status;
  final ApprovalStatus? approval;
  final LoanStatus? loan;
  final StatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final effectiveTone = status != null
        ? switch (status!) {
            AssetStatus.available => StatusTone.positive,
            AssetStatus.checkedOut => StatusTone.info,
            AssetStatus.overdue ||
            AssetStatus.missing ||
            AssetStatus.damaged ||
            AssetStatus.quarantined => StatusTone.danger,
            AssetStatus.underMaintenance ||
            AssetStatus.retired => StatusTone.warning,
          }
        : approval != null
        ? switch (approval!) {
            ApprovalStatus.approved => StatusTone.positive,
            ApprovalStatus.pending ||
            ApprovalStatus.needsClarification => StatusTone.warning,
            ApprovalStatus.rejected => StatusTone.danger,
          }
        : loan != null
        ? switch (loan!) {
            LoanStatus.active => StatusTone.info,
            LoanStatus.overdue => StatusTone.danger,
            LoanStatus.returned => StatusTone.positive,
            LoanStatus.pendingAuthorization => StatusTone.warning,
          }
        : tone;
    final color = switch (effectiveTone) {
      StatusTone.positive => c.accent,
      StatusTone.warning => c.warning,
      StatusTone.danger => c.danger,
      StatusTone.info => c.info,
      StatusTone.neutral => c.textSecondary,
    };
    final text =
        status?.label ??
        approval?.name.toUpperCase().replaceAll(
          'needsClarification',
          'NEEDS CLARIFICATION',
        ) ??
        loan?.name.toUpperCase() ??
        label;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.monoFont,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w500,
          letterSpacing: .4,
          color: color,
        ),
      ),
    );
  }
}

enum StatusTone { positive, warning, danger, info, neutral }

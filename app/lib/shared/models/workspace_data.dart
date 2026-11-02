import '../../features/approvals/data/models/approval_record.dart';
import '../../features/archives/data/models/archive_record.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/loans/data/models/loan_record.dart';
import 'app_settings.dart';
import 'app_user.dart';
import 'audit_event.dart';

class WorkspaceData {
  const WorkspaceData({
    required this.assets,
    required this.loans,
    required this.approvals,
    required this.damages,
    required this.disposals,
    required this.audit,
    required this.users,
    required this.settings,
  });
  final List<ToolAsset> assets;
  final List<LoanRecord> loans;
  final List<ApprovalRecord> approvals;
  final List<DamageRecord> damages;
  final List<DisposalRecord> disposals;
  final List<AuditEvent> audit;
  final List<AppUser> users;
  final AppSettings settings;

  factory WorkspaceData.empty() => WorkspaceData(
    assets: const [],
    loans: const [],
    approvals: const [],
    damages: const [],
    disposals: const [],
    audit: const [],
    users: const [],
    settings: const AppSettings(),
  );

  ToolAsset? assetById(String id) {
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  int countStatus(AssetStatus status) =>
      assets.where((asset) => asset.status == status).length;
  int get damagedCount => assets
      .where(
        (a) =>
            a.status == AssetStatus.damaged ||
            a.status == AssetStatus.quarantined,
      )
      .length;
  int get pendingApprovals =>
      approvals.where((a) => a.status == ApprovalStatus.pending).length;
  double get totalPurchaseValue =>
      assets.fold(0, (sum, asset) => sum + asset.totalPurchaseValuePkr);
  double get netBookValue =>
      assets.fold(0, (sum, asset) => sum + asset.netBookValue);
  double get totalDepreciation =>
      assets.fold(0, (sum, asset) => sum + asset.accumulatedDepreciation);
  List<LoanRecord> get activeLoans => loans
      .where(
        (loan) =>
            loan.status == LoanStatus.active ||
            loan.status == LoanStatus.overdue,
      )
      .toList();
}

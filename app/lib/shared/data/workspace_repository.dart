import '../../features/approvals/data/models/approval_record.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/loans/data/models/loan_record.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../models/workspace_data.dart';

abstract interface class WorkspaceRepository {
  Future<WorkspaceData> load();
  Future<CheckoutResult> requestCheckout(CheckoutDraft draft, AppUser actor);
  Future<void> completeHandover(String approvalId, AppUser actor);
  Future<void> decideApproval(
    String id,
    ApprovalStatus decision,
    String note,
    AppUser manager,
  );
  Future<void> returnAsset(
    String assetId,
    bool damaged,
    String notes,
    AppUser actor,
    int evidenceCount,
  );
  Future<void> reportDamage(
    String assetId,
    String notes,
    AppUser actor,
    int evidenceCount,
  );
  Future<void> registerAsset(ToolAsset asset, AppUser actor);
  Future<void> updatePhoto(String assetId, String photoUrl, AppUser actor);
  Future<void> updateSettings(AppSettings settings, AppUser manager);
  Future<void> updateNotificationPreferences(
    AppSettings settings,
    AppUser actor,
  );
  Future<void> createLender(AppUser user, AppUser manager);
  Future<void> setUserActive(String userId, bool active, AppUser manager);
  Future<void> initiatePasswordReset(String userId, AppUser manager);
  Future<void> revokeSessions(String userId, AppUser manager);
}

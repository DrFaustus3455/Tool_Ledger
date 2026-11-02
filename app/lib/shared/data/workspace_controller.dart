import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/approvals/data/models/approval_record.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/loans/data/models/loan_record.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../models/workspace_data.dart';
import 'mock_workspace_repository.dart';
import 'workspace_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => MockWorkspaceRepository(),
);
final workspaceProvider =
    AsyncNotifierProvider<WorkspaceController, WorkspaceData>(
      WorkspaceController.new,
    );

class WorkspaceController extends AsyncNotifier<WorkspaceData> {
  WorkspaceRepository get _repo => ref.read(workspaceRepositoryProvider);
  @override
  Future<WorkspaceData> build() => _repo.load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.load);
  }

  Future<void> _run(Future<void> Function() action) async {
    final previous = state;
    try {
      await action();
      state = AsyncData(await _repo.load());
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<CheckoutResult> requestCheckout(
    CheckoutDraft draft,
    AppUser actor,
  ) async {
    final result = await _repo.requestCheckout(draft, actor);
    state = AsyncData(await _repo.load());
    return result;
  }

  Future<void> completeHandover(String id, AppUser actor) =>
      _run(() => _repo.completeHandover(id, actor));
  Future<void> decideApproval(
    String id,
    ApprovalStatus decision,
    String note,
    AppUser manager,
  ) => _run(() => _repo.decideApproval(id, decision, note, manager));
  Future<void> returnAsset(
    String id,
    bool damaged,
    String notes,
    AppUser actor,
    int evidenceCount,
  ) => _run(() => _repo.returnAsset(id, damaged, notes, actor, evidenceCount));
  Future<void> reportDamage(
    String id,
    String notes,
    AppUser actor,
    int evidenceCount,
  ) => _run(() => _repo.reportDamage(id, notes, actor, evidenceCount));
  Future<void> registerAsset(ToolAsset asset, AppUser actor) =>
      _run(() => _repo.registerAsset(asset, actor));
  Future<void> updatePhoto(String id, String url, AppUser actor) =>
      _run(() => _repo.updatePhoto(id, url, actor));
  Future<void> updateSettings(AppSettings settings, AppUser manager) =>
      _run(() => _repo.updateSettings(settings, manager));
  Future<void> updateNotificationPreferences(
    AppSettings settings,
    AppUser actor,
  ) => _run(() => _repo.updateNotificationPreferences(settings, actor));
  Future<void> createLender(AppUser user, AppUser manager) =>
      _run(() => _repo.createLender(user, manager));
  Future<void> setUserActive(String id, bool active, AppUser manager) =>
      _run(() => _repo.setUserActive(id, active, manager));
  Future<void> initiatePasswordReset(String id, AppUser manager) =>
      _run(() => _repo.initiatePasswordReset(id, manager));
  Future<void> revokeSessions(String id, AppUser manager) =>
      _run(() => _repo.revokeSessions(id, manager));
}

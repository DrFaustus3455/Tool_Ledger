import 'package:flutter_test/flutter_test.dart';
import 'package:toolledger/features/approvals/data/models/approval_record.dart';
import 'package:toolledger/features/inventory/data/models/tool_asset.dart';
import 'package:toolledger/features/loans/data/models/loan_record.dart';
import 'package:toolledger/shared/data/mock_workspace_repository.dart';
import 'package:toolledger/shared/models/app_user.dart';

const lender = AppUser(
  id: 'U-TEST-L',
  employeeId: 'OES-LND-TEST',
  username: 'lender@test.local',
  displayName: 'Test Lender',
  role: UserRole.lender,
  department: 'Product Support',
);
const manager = AppUser(
  id: 'U-TEST-M',
  employeeId: 'OES-MGR-TEST',
  username: 'manager@test.local',
  displayName: 'Test Manager',
  role: UserRole.manager,
  department: 'Product Support',
);

CheckoutDraft draft(String assetId) => CheckoutDraft(
  assetId: assetId,
  borrowerName: 'Test Mechanic',
  borrowerEmployeeId: 'MECH-999',
  department: 'Mechanical Support',
  workOrder: 'WO-GEN-TEST',
  purpose: 'Generator maintenance verification',
  dueDate: DateTime.now().add(const Duration(days: 3)),
);

void main() {
  late MockWorkspaceRepository repository;

  setUp(() => repository = MockWorkspaceRepository());

  test(
    'standard checkout creates one loan and prevents duplicate issue',
    () async {
      final result = await repository.requestCheckout(
        draft('TL-SOCK-021'),
        lender,
      );
      expect(result, CheckoutResult.checkedOut);
      final data = await repository.load();
      expect(data.assetById('TL-SOCK-021')!.status, AssetStatus.checkedOut);
      expect(
        data.activeLoans.where((loan) => loan.assetId == 'TL-SOCK-021'),
        hasLength(1),
      );
      await expectLater(
        repository.requestCheckout(draft('TL-SOCK-021'), lender),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'high-value checkout stays pending until approval and final handover',
    () async {
      final before = await repository.load();
      final initialLoans = before.loans.length;
      final result = await repository.requestCheckout(
        draft('TL-BOR-023'),
        lender,
      );
      expect(result, CheckoutResult.approvalRequired);
      var data = await repository.load();
      expect(data.loans, hasLength(initialLoans));
      expect(data.assetById('TL-BOR-023')!.status, AssetStatus.available);
      final approval = data.approvals.firstWhere(
        (item) =>
            item.assetId == 'TL-BOR-023' &&
            item.status == ApprovalStatus.pending,
      );

      await expectLater(
        repository.completeHandover(approval.id, lender),
        throwsA(isA<StateError>()),
      );
      await repository.decideApproval(
        approval.id,
        ApprovalStatus.approved,
        'Verified work order',
        manager,
      );
      await repository.completeHandover(approval.id, lender);
      data = await repository.load();
      expect(data.assetById('TL-BOR-023')!.status, AssetStatus.checkedOut);
      expect(
        data.loans.firstWhere((loan) => loan.approvalId == approval.id).status,
        LoanStatus.active,
      );
      await expectLater(
        repository.completeHandover(approval.id, lender),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'availability is rechecked when two approvals target the same asset',
    () async {
      await repository.requestCheckout(draft('TL-BOR-023'), lender);
      await repository.requestCheckout(draft('TL-BOR-023'), lender);
      final data = await repository.load();
      final requests = data.approvals
          .where(
            (item) =>
                item.assetId == 'TL-BOR-023' &&
                item.status == ApprovalStatus.pending,
          )
          .toList();
      for (final request in requests) {
        await repository.decideApproval(
          request.id,
          ApprovalStatus.approved,
          'Reviewed',
          manager,
        );
      }
      await repository.completeHandover(requests.first.id, lender);
      await expectLater(
        repository.completeHandover(requests.last.id, lender),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('rejected authorization cannot create a loan', () async {
    await repository.requestCheckout(draft('TL-BOR-023'), lender);
    final data = await repository.load();
    final approval = data.approvals.firstWhere(
      (item) =>
          item.assetId == 'TL-BOR-023' && item.status == ApprovalStatus.pending,
    );
    await repository.decideApproval(
      approval.id,
      ApprovalStatus.rejected,
      'Work order not verified',
      manager,
    );
    await expectLater(
      repository.completeHandover(approval.id, lender),
      throwsA(isA<StateError>()),
    );
    expect(
      (await repository.load()).assetById('TL-BOR-023')!.status,
      AssetStatus.available,
    );
  });

  test('lender cannot decide an approval', () async {
    await expectLater(
      repository.decideApproval(
        'APR-1042',
        ApprovalStatus.approved,
        'Attempted bypass',
        lender,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'serviceable return closes custody and clears borrower fields',
    () async {
      await repository.requestCheckout(draft('TL-SOCK-021'), lender);
      await repository.returnAsset('TL-SOCK-021', false, '', lender, 0);
      final data = await repository.load();
      final asset = data.assetById('TL-SOCK-021')!;
      expect(asset.status, AssetStatus.available);
      expect(asset.currentBorrower, isEmpty);
      expect(asset.expectedReturnDate, isNull);
      expect(
        data.loans
            .firstWhere(
              (loan) =>
                  loan.assetId == 'TL-SOCK-021' && loan.returnDate != null,
            )
            .status,
        LoanStatus.returned,
      );
    },
  );

  test(
    'damaged return quarantines asset and preserves evidence record',
    () async {
      final before = (await repository.load()).damages.length;
      await repository.requestCheckout(draft('TL-SOCK-021'), lender);
      await repository.returnAsset(
        'TL-SOCK-021',
        true,
        'Cracked housing found on return',
        lender,
        2,
      );
      final data = await repository.load();
      expect(data.assetById('TL-SOCK-021')!.status, AssetStatus.quarantined);
      expect(data.damages, hasLength(before + 1));
      expect(data.damages.first.evidenceCount, 2);
    },
  );

  test('standalone damage report marks asset damaged', () async {
    await repository.reportDamage(
      'TL-DIAL-016',
      'Indicator spindle is bent beyond tolerance',
      lender,
      1,
    );
    expect(
      (await repository.load()).assetById('TL-DIAL-016')!.status,
      AssetStatus.damaged,
    );
  });
}

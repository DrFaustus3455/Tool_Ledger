import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/approvals/data/models/approval_record.dart';
import '../../features/archives/data/models/archive_record.dart';
import '../../features/inventory/data/models/tool_asset.dart';
import '../../features/loans/data/models/loan_record.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../models/audit_event.dart';
import '../models/workspace_data.dart';
import 'workspace_repository.dart';

class MockWorkspaceRepository implements WorkspaceRepository {
  MockWorkspaceRepository() {
    _seed();
  }

  final _assets = <ToolAsset>[];
  final _loans = <LoanRecord>[];
  final _approvals = <ApprovalRecord>[];
  final _damages = <DamageRecord>[];
  final _disposals = <DisposalRecord>[];
  final _audit = <AuditEvent>[];
  final _users = <AppUser>[];
  final _pendingAssets = <String, ToolAsset>{};
  AppSettings _settings = const AppSettings();
  var _sequence = 100;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  Future<void> _latency() => Future.delayed(const Duration(milliseconds: 220));

  @override
  Future<WorkspaceData> load() async {
    await _latency();
    return WorkspaceData(
      assets: List.unmodifiable(_assets),
      loans: List.unmodifiable(_loans),
      approvals: List.unmodifiable(_approvals),
      damages: List.unmodifiable(_damages),
      disposals: List.unmodifiable(_disposals),
      audit: List.unmodifiable(_audit),
      users: List.unmodifiable(_users),
      settings: _settings,
    );
  }

  @override
  Future<CheckoutResult> requestCheckout(
    CheckoutDraft draft,
    AppUser actor,
  ) async {
    await _latency();
    final index = _assets.indexWhere((a) => a.id == draft.assetId);
    if (index < 0 || !_assets[index].isLendable) {
      throw StateError(
        'Asset is no longer available. Refresh and verify its condition.',
      );
    }
    final asset = _assets[index];
    final requiresApproval =
        asset.isRestricted ||
        _settings.restrictedCategories.contains(asset.equipmentType) ||
        asset.totalPurchaseValuePkr >= _settings.approvalThresholdPkr;
    if (requiresApproval) {
      _approvals.insert(
        0,
        ApprovalRecord(
          id: _id('APR'),
          assetId: asset.id,
          assetName: asset.description,
          type: ApprovalType.expensiveLending,
          requestedBy: actor.displayName,
          requestedByEmployeeId: actor.employeeId,
          reason: draft.purpose,
          requestedAt: DateTime.now(),
          status: ApprovalStatus.pending,
          amountPkr: asset.totalPurchaseValuePkr,
          borrowerDetails:
              '${draft.borrowerName} • ${draft.borrowerEmployeeId} • ${draft.department} • ${draft.workOrder}',
          checkoutDraft: draft,
        ),
      );
      _log(
        actor.displayName,
        'Approval requested',
        asset.id,
        'High-value checkout held before handover.',
        'Approvals',
      );
      return CheckoutResult.approvalRequired;
    }
    _createLoan(draft, actor, asset);
    return CheckoutResult.checkedOut;
  }

  void _createLoan(
    CheckoutDraft draft,
    AppUser actor,
    ToolAsset asset, {
    String? approvalId,
  }) {
    final now = DateTime.now();
    _loans.insert(
      0,
      LoanRecord(
        id: _id('LN'),
        assetId: asset.id,
        assetName: asset.description,
        borrowerName: draft.borrowerName,
        borrowerEmployeeId: draft.borrowerEmployeeId,
        department: draft.department,
        workOrder: draft.workOrder,
        purpose: draft.purpose,
        issuedBy: actor.displayName,
        issueDate: now,
        dueDate: draft.dueDate,
        status: LoanStatus.active,
        approvalId: approvalId,
      ),
    );
    final index = _assets.indexWhere((a) => a.id == asset.id);
    _assets[index] = asset.copyWith(
      status:
          LoanStatus.active == LoanStatus.active && draft.dueDate.isBefore(now)
          ? AssetStatus.overdue
          : AssetStatus.checkedOut,
      currentBorrower: '${draft.borrowerName} (${draft.borrowerEmployeeId})',
      expectedReturnDate: draft.dueDate,
      lastUpdated: now,
    );
    _log(
      actor.displayName,
      'Physical handover confirmed',
      asset.id,
      '${draft.borrowerName} • ${draft.workOrder}',
      'Lending',
    );
  }

  @override
  Future<void> completeHandover(String approvalId, AppUser actor) async {
    await _latency();
    final approval = _approvals.firstWhere((a) => a.id == approvalId);
    if (approval.status != ApprovalStatus.approved ||
        approval.checkoutDraft == null) {
      throw StateError('Authorization is not valid for handover.');
    }
    final asset = _assets.firstWhere((a) => a.id == approval.assetId);
    if (!asset.isLendable) {
      throw StateError(
        'Availability recheck failed. This asset has already been issued or changed state.',
      );
    }
    _createLoan(approval.checkoutDraft!, actor, asset, approvalId: approvalId);
  }

  @override
  Future<void> decideApproval(
    String id,
    ApprovalStatus decision,
    String note,
    AppUser manager,
  ) async {
    await _latency();
    if (manager.role != UserRole.manager) {
      throw StateError('Manager authorization required.');
    }
    if (note.trim().isEmpty) throw StateError('A decision note is required.');
    final index = _approvals.indexWhere((a) => a.id == id);
    if (index < 0 || _approvals[index].status != ApprovalStatus.pending) {
      throw StateError('This request has already been decided.');
    }
    final current = _approvals[index];
    _approvals[index] = current.copyWith(
      status: decision,
      decisionNote: note.trim(),
      decidedBy: manager.displayName,
      decidedAt: DateTime.now(),
    );
    if (decision == ApprovalStatus.approved &&
        current.type == ApprovalType.newEquipment &&
        _pendingAssets.containsKey(current.assetId)) {
      _assets.add(_pendingAssets.remove(current.assetId)!);
    }
    _log(
      manager.displayName,
      'Approval ${decision.name}',
      current.assetId,
      note.trim(),
      'Approvals',
    );
  }

  @override
  Future<void> returnAsset(
    String assetId,
    bool damaged,
    String notes,
    AppUser actor,
    int evidenceCount,
  ) async {
    await _latency();
    final loanIndex = _loans.indexWhere(
      (l) =>
          l.assetId == assetId &&
          (l.status == LoanStatus.active || l.status == LoanStatus.overdue),
    );
    if (loanIndex < 0) {
      throw StateError('No active loan was found for this asset.');
    }
    final assetIndex = _assets.indexWhere((a) => a.id == assetId);
    final asset = _assets[assetIndex];
    final now = DateTime.now();
    _loans[loanIndex] = _loans[loanIndex].copyWith(
      status: LoanStatus.returned,
      returnDate: now,
      returnCondition: damaged ? 'Damaged: $notes' : 'Serviceable',
    );
    _assets[assetIndex] = asset.copyWith(
      status: damaged ? AssetStatus.quarantined : AssetStatus.available,
      currentBorrower: '',
      expectedReturnDate: null,
      condition: damaged ? 'Quarantined — inspection required' : 'Serviceable',
      lyingAt: damaged ? 'Quarantine Bay Q-02' : 'Tool Store A',
      lastUpdated: now,
    );
    if (damaged) _addDamage(asset, notes, actor, evidenceCount);
    _log(
      actor.displayName,
      damaged ? 'Returned and quarantined' : 'Return recorded',
      assetId,
      damaged ? notes : 'Serviceable condition verified.',
      'Lending',
    );
  }

  @override
  Future<void> reportDamage(
    String assetId,
    String notes,
    AppUser actor,
    int evidenceCount,
  ) async {
    await _latency();
    if (notes.trim().length < 10) {
      throw StateError('Provide a detailed damage description.');
    }
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index < 0) throw StateError('Asset not found.');
    final asset = _assets[index];
    _assets[index] = asset.copyWith(
      status: AssetStatus.damaged,
      condition: 'Damaged — report submitted',
      lyingAt: 'Damage Holding Bay',
      lastUpdated: DateTime.now(),
    );
    _addDamage(asset, notes, actor, evidenceCount);
    _log(actor.displayName, 'Damage reported', assetId, notes, 'Damage');
  }

  void _addDamage(
    ToolAsset asset,
    String notes,
    AppUser actor,
    int evidenceCount,
  ) {
    _damages.insert(
      0,
      DamageRecord(
        id: _id('DMG'),
        assetId: asset.id,
        description: notes,
        reportedBy: actor.displayName,
        damageDate: DateTime.now(),
        originalCostPkr: asset.totalPurchaseValuePkr,
        accumulatedDepreciationPkr: asset.accumulatedDepreciation,
        netBookValuePkr: asset.netBookValue,
        repairStatus: 'Awaiting assessment',
        evidenceCount: evidenceCount,
      ),
    );
  }

  @override
  Future<void> registerAsset(ToolAsset asset, AppUser actor) async {
    await _latency();
    if (_assets.any((a) => a.id == asset.id) ||
        _pendingAssets.containsKey(asset.id)) {
      throw StateError('Asset ID already exists.');
    }
    _pendingAssets[asset.id] = asset;
    _approvals.insert(
      0,
      ApprovalRecord(
        id: _id('APR'),
        assetId: asset.id,
        assetName: asset.description,
        type: ApprovalType.newEquipment,
        requestedBy: actor.displayName,
        requestedByEmployeeId: actor.employeeId,
        reason: 'New equipment registration',
        requestedAt: DateTime.now(),
        status: ApprovalStatus.pending,
        amountPkr: asset.totalPurchaseValuePkr,
      ),
    );
    _log(
      actor.displayName,
      'Registration submitted',
      asset.id,
      'Pending manager authorization.',
      'Inventory',
    );
  }

  @override
  Future<void> updatePhoto(
    String assetId,
    String photoUrl,
    AppUser actor,
  ) async {
    await _latency();
    final index = _assets.indexWhere((a) => a.id == assetId);
    if (index < 0) throw StateError('Asset not found.');
    _assets[index] = _assets[index].copyWith(
      photoUrl: photoUrl,
      lastUpdated: DateTime.now(),
    );
    _log(
      actor.displayName,
      'Photograph updated',
      assetId,
      'Mock private-storage reference updated.',
      'Inventory',
    );
  }

  @override
  Future<void> updateSettings(AppSettings settings, AppUser manager) async {
    await _latency();
    if (manager.role != UserRole.manager) {
      throw StateError('Manager authorization required.');
    }
    if (settings.approvalThresholdPkr < 0 ||
        settings.defaultReturnDays < 1 ||
        settings.defaultUsefulLifeYears < 1) {
      throw StateError('Invalid business rule values.');
    }
    _settings = settings;
    _log(
      manager.displayName,
      'Business rules updated',
      'SETTINGS',
      'Approval threshold PKR ${settings.approvalThresholdPkr.toStringAsFixed(0)}',
      'Security',
    );
  }

  @override
  Future<void> updateNotificationPreferences(
    AppSettings settings,
    AppUser actor,
  ) async {
    await _latency();
    _settings = _settings.copyWith(
      overdueNotifications: settings.overdueNotifications,
      approvalNotifications: settings.approvalNotifications,
      dailyDigest: settings.dailyDigest,
    );
    _log(
      actor.displayName,
      'Notification preferences updated',
      actor.employeeId,
      'User preference change.',
      'Settings',
    );
  }

  @override
  Future<void> createLender(AppUser user, AppUser manager) async {
    await _latency();
    if (manager.role != UserRole.manager || user.role != UserRole.lender) {
      throw StateError('Only lender accounts can be created here.');
    }
    if (_users.any(
      (u) => u.employeeId == user.employeeId || u.username == user.username,
    )) {
      throw StateError('Employee ID or username already exists.');
    }
    _users.add(user);
    _log(
      manager.displayName,
      'Lender account created',
      user.employeeId,
      user.displayName,
      'Accounts',
    );
  }

  @override
  Future<void> setUserActive(
    String userId,
    bool active,
    AppUser manager,
  ) async {
    await _latency();
    final index = _users.indexWhere((u) => u.id == userId);
    if (index < 0) throw StateError('Account not found.');
    if (_users[index].role == UserRole.manager) {
      throw StateError('The primary manager account cannot be disabled.');
    }
    _users[index] = _users[index].copyWith(
      isActive: active,
      activeSessions: active ? _users[index].activeSessions : 0,
    );
    _log(
      manager.displayName,
      active ? 'Account enabled' : 'Account disabled',
      _users[index].employeeId,
      _users[index].displayName,
      'Accounts',
    );
  }

  @override
  Future<void> initiatePasswordReset(String userId, AppUser manager) async {
    await _latency();
    final user = _users.firstWhere((u) => u.id == userId);
    _log(
      manager.displayName,
      'Password reset initiated',
      user.employeeId,
      'One-time backend flow requested; no password exposed.',
      'Accounts',
    );
  }

  @override
  Future<void> revokeSessions(String userId, AppUser manager) async {
    await _latency();
    final index = _users.indexWhere((u) => u.id == userId);
    _users[index] = _users[index].copyWith(activeSessions: 0);
    _log(
      manager.displayName,
      'Sessions revoked',
      _users[index].employeeId,
      'All active sessions invalidated.',
      'Accounts',
    );
  }

  void _log(
    String actor,
    String action,
    String recordId,
    String details,
    String category,
  ) {
    _audit.insert(
      0,
      AuditEvent(
        id: _id('AUD'),
        actor: actor,
        action: action,
        recordId: recordId,
        timestamp: DateTime.now(),
        details: details,
        category: category,
      ),
    );
  }

  void _seed() {
    final now = DateTime.now();
    _users.addAll([
      AppUser(
        id: 'U-001',
        employeeId: 'OES-MGR-01',
        username: 'manager@toolledger.demo',
        displayName: 'Ayesha Khan',
        role: UserRole.manager,
        department: 'Product Support',
        lastLogin: now.subtract(const Duration(hours: 2)),
      ),
      AppUser(
        id: 'U-002',
        employeeId: 'OES-LND-14',
        username: 'lender@toolledger.demo',
        displayName: 'Bilal Ahmed',
        role: UserRole.lender,
        department: 'Product Support',
        lastLogin: now.subtract(const Duration(minutes: 24)),
      ),
      AppUser(
        id: 'U-003',
        employeeId: 'OES-LND-19',
        username: 's.raza@toolledger.demo',
        displayName: 'Sana Raza',
        role: UserRole.lender,
        department: 'Product Support',
        lastLogin: now.subtract(const Duration(days: 2)),
        activeSessions: 0,
      ),
    ]);
    final specs =
        <
          (
            String,
            String,
            String,
            String,
            String,
            double,
            AssetStatus,
            String,
            String,
          )
        >[
          (
            'TL-TORQ-001',
            'Digital Torque Wrench 40–200 Nm',
            'TW-200D',
            'Norbar',
            'Torque Tools',
            185000,
            AssetStatus.available,
            'Mechanical Support',
            'Tool Store A',
          ),
          (
            'TL-ANA-014',
            'Insulation Resistance Analyzer 5 kV',
            'MI-5050',
            'Megger',
            'Precision Instruments',
            780000,
            AssetStatus.checkedOut,
            'Electrical Support',
            'Issued — Generator Bay 3',
          ),
          (
            'TL-ALIGN-005',
            'Laser Shaft Alignment System',
            'S660',
            'SKF',
            'Precision Instruments',
            1250000,
            AssetStatus.available,
            'Rotating Equipment',
            'Calibration Cabinet C-01',
          ),
          (
            'TL-MULT-003',
            'Industrial True RMS Multimeter',
            '287C',
            'Fluke',
            'Electrical Test',
            128500,
            AssetStatus.available,
            'Electrical Support',
            'Tool Store A',
          ),
          (
            'TL-VIB-002',
            'Vibration Analysis Kit',
            'VB-8',
            'Commtest',
            'Precision Instruments',
            645000,
            AssetStatus.damaged,
            'Rotating Equipment',
            'Damage Holding Bay',
          ),
          (
            'TL-HYD-008',
            'Hydraulic Puller Set 30 Ton',
            'HP-30',
            'Enerpac',
            'Hydraulic Tools',
            395000,
            AssetStatus.overdue,
            'Mechanical Support',
            'Issued — DG Overhaul',
          ),
          (
            'TL-CRN-011',
            'Portable Load Cell 10 Ton',
            'LC-10T',
            'Straightpoint',
            'Lifting & Measurement',
            515000,
            AssetStatus.available,
            'Mechanical Support',
            'Lifting Gear Rack',
          ),
          (
            'TL-SOCK-021',
            'Impact Socket Set 1 in Drive',
            'IS-42',
            'Proto',
            'Hand Tools',
            89000,
            AssetStatus.available,
            'Mechanical Support',
            'Tool Store B',
          ),
          (
            'TL-MISS-009',
            'Fuel Pressure Test Kit',
            'FP-750',
            'Bosch',
            'Engine Diagnostics',
            164000,
            AssetStatus.missing,
            'Engine Support',
            'Last seen — Workshop 2',
          ),
          (
            'TL-PULL-006',
            'Bearing Heater 22 kVA',
            'BH-22',
            'SKF',
            'Workshop Equipment',
            460000,
            AssetStatus.underMaintenance,
            'Rotating Equipment',
            'Maintenance Bench M-04',
          ),
          (
            'TL-DIAL-016',
            'Dial Indicator Magnetic Base Set',
            'DI-10',
            'Mitutoyo',
            'Measurement',
            74000,
            AssetStatus.available,
            'Mechanical Support',
            'Metrology Drawer 2',
          ),
          (
            'TL-MEG-018',
            'Hand Crank Insulation Tester 1 kV',
            'MJ-15',
            'Megger',
            'Electrical Test',
            210000,
            AssetStatus.checkedOut,
            'Electrical Support',
            'Issued — Generator Bay 1',
          ),
          (
            'TL-GEN-010',
            'Obsolete Engine Compression Gauge',
            'CG-90',
            'Snap-on',
            'Engine Diagnostics',
            62000,
            AssetStatus.retired,
            'Engine Support',
            'Disposed Archive',
          ),
          (
            'TL-BOR-023',
            'Industrial Video Borescope',
            'IPLX',
            'Olympus',
            'Precision Instruments',
            920000,
            AssetStatus.available,
            'Engine Support',
            'Calibration Cabinet C-02',
          ),
          (
            'TL-DRIL-025',
            'Magnetic Drill Press 50 mm',
            'MD-50',
            'Fein',
            'Workshop Equipment',
            335000,
            AssetStatus.available,
            'Mechanical Support',
            'Tool Store C',
          ),
          (
            'TL-CALI-027',
            'Pressure Calibrator 700 bar',
            'P700',
            'Druck',
            'Precision Instruments',
            1130000,
            AssetStatus.available,
            'Instrumentation',
            'Calibration Cabinet C-03',
          ),
        ];
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final purchase = DateTime(2019 + (i % 6), (i % 12) + 1, (i % 20) + 1);
      final price = s.$6;
      _assets.add(
        ToolAsset(
          id: s.$1,
          serialNumber: 'SN-${2020 + i}-${(1048 + i * 79).toString()}',
          description: s.$2,
          quantity: 1,
          partNumber: s.$3,
          series: 'Industrial/${s.$3}',
          manufacturer: s.$4,
          equipmentType: s.$5,
          legacyTypePrimary: i.isEven ? 'TYPE-A' : 'TYPE-B',
          legacyTypeSecondary: 'IMPORT-${i % 3}',
          legacyDepreciationPrimary: price * .17,
          legacyDepreciationSecondary: price * .16,
          unitPricePkr: price * .86,
          extendedPricePkr: price * .86,
          historicalGstAmountPkr: price * .14,
          historicalGstRate: .14,
          totalPurchaseValuePkr: price,
          foreignCurrencyValue: price / 278,
          foreignCurrencyCode: 'USD',
          purchaseDate: purchase,
          valuationDate: now,
          usefulLifeYears: 5 + i % 4,
          residualValuePkr: price * .05,
          historicalAccumulatedDepreciationPkr: i == 4
              ? price * .12
              : price * .45,
          vendor: i % 2 == 0
              ? 'OES Industrial Supply'
              : 'Global Engineering Traders',
          isImported: i % 3 != 0,
          oesPurchaseOrder: 'OES-PO-${4200 + i}',
          billNumber: 'BILL-${9100 + i}',
          billDate: purchase.add(const Duration(days: 3)),
          department: s.$8,
          lyingAt: s.$9,
          departmentCode: 'PS-${100 + i % 5}',
          condition: switch (s.$7) {
            AssetStatus.damaged => 'Impact damage — held for assessment',
            AssetStatus.missing => 'Unverified — search active',
            AssetStatus.retired => 'Disposed',
            AssetStatus.underMaintenance => 'Service in progress',
            _ => 'Serviceable',
          },
          issuedTo:
              s.$7 == AssetStatus.checkedOut || s.$7 == AssetStatus.overdue
              ? 'Generator Maintenance'
              : '',
          transferredTo: '',
          purpose: 'Generator maintenance and overhaul',
          remarks: i == 4
              ? 'Legacy depreciation differs from configured policy; review required.'
              : 'Register migrated without loss of source fields.',
          lastUpdated: now.subtract(Duration(hours: i + 1)),
          currentBorrower: s.$7 == AssetStatus.checkedOut
              ? (i == 1 ? 'Hamza Yousaf (MECH-208)' : 'Usman Ali (MECH-116)')
              : s.$7 == AssetStatus.overdue
              ? 'Danish Iqbal (MECH-173)'
              : '',
          expectedReturnDate: s.$7 == AssetStatus.overdue
              ? now.subtract(const Duration(days: 3))
              : s.$7 == AssetStatus.checkedOut
              ? now.add(Duration(days: i + 2))
              : null,
          status: s.$7,
          isRestricted: s.$5 == 'Precision Instruments',
          photoUrl: 'assets/images/tool_${i % 4}.png',
        ),
      );
    }
    _loans.addAll([
      LoanRecord(
        id: 'LN-1001',
        assetId: 'TL-ANA-014',
        assetName: 'Insulation Resistance Analyzer 5 kV',
        borrowerName: 'Hamza Yousaf',
        borrowerEmployeeId: 'MECH-208',
        department: 'Electrical Support',
        workOrder: 'WO-GEN-4418',
        purpose: 'Stator winding insulation test',
        issuedBy: 'Bilal Ahmed',
        issueDate: now.subtract(const Duration(days: 2, hours: 3)),
        dueDate: now.add(const Duration(days: 3)),
        status: LoanStatus.active,
      ),
      LoanRecord(
        id: 'LN-1002',
        assetId: 'TL-HYD-008',
        assetName: 'Hydraulic Puller Set 30 Ton',
        borrowerName: 'Danish Iqbal',
        borrowerEmployeeId: 'MECH-173',
        department: 'Mechanical Support',
        workOrder: 'WO-GEN-4391',
        purpose: 'Coupling removal during DG overhaul',
        issuedBy: 'Sana Raza',
        issueDate: now.subtract(const Duration(days: 12)),
        dueDate: now.subtract(const Duration(days: 3)),
        status: LoanStatus.overdue,
      ),
      LoanRecord(
        id: 'LN-1003',
        assetId: 'TL-MEG-018',
        assetName: 'Hand Crank Insulation Tester 1 kV',
        borrowerName: 'Usman Ali',
        borrowerEmployeeId: 'MECH-116',
        department: 'Electrical Support',
        workOrder: 'WO-GEN-4420',
        purpose: 'Alternator cable verification',
        issuedBy: 'Bilal Ahmed',
        issueDate: now.subtract(const Duration(days: 1, hours: 5)),
        dueDate: now.add(const Duration(days: 4)),
        status: LoanStatus.active,
      ),
      LoanRecord(
        id: 'LN-0997',
        assetId: 'TL-TORQ-001',
        assetName: 'Digital Torque Wrench 40–200 Nm',
        borrowerName: 'Hamza Yousaf',
        borrowerEmployeeId: 'MECH-208',
        department: 'Mechanical Support',
        workOrder: 'WO-GEN-4376',
        purpose: 'Cylinder head bolt verification',
        issuedBy: 'Sana Raza',
        issueDate: now.subtract(const Duration(days: 18)),
        dueDate: now.subtract(const Duration(days: 15)),
        returnDate: now.subtract(const Duration(days: 15)),
        returnCondition: 'Serviceable',
        status: LoanStatus.returned,
      ),
      LoanRecord(
        id: 'LN-0993',
        assetId: 'TL-SOCK-021',
        assetName: 'Impact Socket Set 1 in Drive',
        borrowerName: 'Danish Iqbal',
        borrowerEmployeeId: 'MECH-173',
        department: 'Mechanical Support',
        workOrder: 'WO-GEN-4351',
        purpose: 'Base frame service',
        issuedBy: 'Bilal Ahmed',
        issueDate: now.subtract(const Duration(days: 25)),
        dueDate: now.subtract(const Duration(days: 22)),
        returnDate: now.subtract(const Duration(days: 21)),
        returnCondition: 'Serviceable',
        status: LoanStatus.returned,
      ),
    ]);
    _damages.add(
      DamageRecord(
        id: 'DMG-001',
        assetId: 'TL-VIB-002',
        description: 'Sensor cable crushed and accelerometer mount cracked during transport.',
        reportedBy: 'Sana Raza',
        damageDate: now.subtract(const Duration(days: 4)),
        originalCostPkr: 645000,
        accumulatedDepreciationPkr: 218000,
        netBookValuePkr: 427000,
        repairStatus: 'Vendor assessment pending',
        evidenceCount: 3,
      ),
    );
    _disposals.add(
      DisposalRecord(
        assetId: 'TL-GEN-010',
        purchaseSummary: 'PO OES-PO-4212 • BILL-9112 • Snap-on',
        disposalDate: now.subtract(const Duration(days: 76)),
        reason: 'Gauge accuracy beyond economical calibration; replaced by digital tester.',
        originalCostPkr: 62000,
        accumulatedDepreciationPkr: 58900,
        netBookValueAtDisposalPkr: 3100,
        proceedsPkr: 4500,
        authorizedBy: 'Ayesha Khan • MFA verified',
        transactionCount: 14,
      ),
    );
    final pendingDraft = CheckoutDraft(
      assetId: 'TL-CALI-027',
      borrowerName: 'Moeen Akhtar',
      borrowerEmployeeId: 'MECH-231',
      department: 'Instrumentation',
      workOrder: 'WO-GEN-4427',
      purpose: 'Pressure switch calibration on standby generator',
      dueDate: now.add(const Duration(days: 2)),
    );
    _approvals.addAll([
      ApprovalRecord(
        id: 'APR-1042',
        assetId: 'TL-CALI-027',
        assetName: 'Pressure Calibrator 700 bar',
        type: ApprovalType.expensiveLending,
        requestedBy: 'Bilal Ahmed',
        requestedByEmployeeId: 'OES-LND-14',
        reason: pendingDraft.purpose,
        requestedAt: now.subtract(const Duration(minutes: 42)),
        status: ApprovalStatus.pending,
        amountPkr: 1130000,
        borrowerDetails:
            'Moeen Akhtar • MECH-231 • Instrumentation • WO-GEN-4427',
        evidenceCount: 1,
        checkoutDraft: pendingDraft,
      ),
      ApprovalRecord(
        id: 'APR-1038',
        assetId: 'TL-ALIGN-005',
        assetName: 'Laser Shaft Alignment System',
        type: ApprovalType.expensiveLending,
        requestedBy: 'Sana Raza',
        requestedByEmployeeId: 'OES-LND-19',
        reason: 'Generator and engine shaft alignment',
        requestedAt: now.subtract(const Duration(days: 1, hours: 2)),
        status: ApprovalStatus.needsClarification,
        amountPkr: 1250000,
        borrowerDetails: 'Kamran Shah • MECH-198 • Rotating Equipment',
        decisionNote:
            'Confirm calibrated certificate validity and return window.',
        decidedBy: 'Ayesha Khan',
        decidedAt: now.subtract(const Duration(days: 1)),
      ),
      ApprovalRecord(
        id: 'APR-1021',
        assetId: 'TL-GEN-010',
        assetName: 'Obsolete Engine Compression Gauge',
        type: ApprovalType.disposal,
        requestedBy: 'Bilal Ahmed',
        requestedByEmployeeId: 'OES-LND-14',
        reason: 'Beyond economical calibration',
        requestedAt: now.subtract(const Duration(days: 80)),
        status: ApprovalStatus.approved,
        amountPkr: 62000,
        decisionNote: 'Approved for recorded salvage disposal.',
        decidedBy: 'Ayesha Khan',
        decidedAt: now.subtract(const Duration(days: 79)),
      ),
    ]);
    final seedEvents = [
      (
        'Bilal Ahmed',
        'Checkout recorded',
        'TL-ANA-014',
        'Hamza Yousaf • WO-GEN-4418',
        'Lending',
      ),
      (
        'Ayesha Khan',
        'Clarification requested',
        'TL-ALIGN-005',
        'Calibration certificate review',
        'Approvals',
      ),
      (
        'Sana Raza',
        'Damage reported',
        'TL-VIB-002',
        '3 evidence photographs attached',
        'Damage',
      ),
      (
        'System',
        'Overdue status applied',
        'TL-HYD-008',
        'Return deadline exceeded by 3 days',
        'Lending',
      ),
      (
        'Ayesha Khan',
        'Valuation reviewed',
        'TL-VIB-002',
        'Legacy depreciation discrepancy flagged',
        'Finance',
      ),
      (
        'Bilal Ahmed',
        'Return recorded',
        'TL-TORQ-001',
        'Serviceable condition verified',
        'Lending',
      ),
      (
        'Ayesha Khan',
        'Export generated',
        'AUDIT-EXP-1008',
        'Filtered active lending history',
        'Exports',
      ),
      (
        'System',
        'Failed sign-in',
        'OES-LND-19',
        'Rate limit event recorded; no password retained',
        'Security',
      ),
    ];
    for (var i = 0; i < seedEvents.length; i++) {
      final e = seedEvents[i];
      _audit.add(
        AuditEvent(
          id: 'AUD-${900 + i}',
          actor: e.$1,
          action: e.$2,
          recordId: e.$3,
          timestamp: now.subtract(Duration(minutes: 18 + i * 47)),
          details: e.$4,
          category: e.$5,
        ),
      );
    }
    debugPrint(
      'ToolLedger mock repository initialized with demonstration data.',
    );
  }
}

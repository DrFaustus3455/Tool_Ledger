import '../../../loans/data/models/loan_record.dart';

enum ApprovalStatus { pending, approved, rejected, needsClarification }

enum ApprovalType {
  expensiveLending,
  newEquipment,
  disposal,
  missingAsset,
  inventoryModification,
  damageDecision,
}

class ApprovalRecord {
  const ApprovalRecord({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.type,
    required this.requestedBy,
    required this.requestedByEmployeeId,
    required this.reason,
    required this.requestedAt,
    required this.status,
    required this.amountPkr,
    this.borrowerDetails,
    this.decisionNote,
    this.decidedBy,
    this.decidedAt,
    this.evidenceCount = 0,
    this.checkoutDraft,
  });

  final String id;
  final String assetId;
  final String assetName;
  final ApprovalType type;
  final String requestedBy;
  final String requestedByEmployeeId;
  final String reason;
  final DateTime requestedAt;
  final ApprovalStatus status;
  final double amountPkr;
  final String? borrowerDetails;
  final String? decisionNote;
  final String? decidedBy;
  final DateTime? decidedAt;
  final int evidenceCount;
  final CheckoutDraft? checkoutDraft;

  String get typeLabel => switch (type) {
    ApprovalType.expensiveLending => 'HIGH-VALUE LENDING',
    ApprovalType.newEquipment => 'NEW EQUIPMENT',
    ApprovalType.disposal => 'ASSET DISPOSAL',
    ApprovalType.missingAsset => 'MISSING DECLARATION',
    ApprovalType.inventoryModification => 'INVENTORY MODIFICATION',
    ApprovalType.damageDecision => 'DAMAGE DECISION',
  };

  ApprovalRecord copyWith({
    ApprovalStatus? status,
    String? decisionNote,
    String? decidedBy,
    DateTime? decidedAt,
  }) => ApprovalRecord(
    id: id,
    assetId: assetId,
    assetName: assetName,
    type: type,
    requestedBy: requestedBy,
    requestedByEmployeeId: requestedByEmployeeId,
    reason: reason,
    requestedAt: requestedAt,
    status: status ?? this.status,
    amountPkr: amountPkr,
    borrowerDetails: borrowerDetails,
    decisionNote: decisionNote ?? this.decisionNote,
    decidedBy: decidedBy ?? this.decidedBy,
    decidedAt: decidedAt ?? this.decidedAt,
    evidenceCount: evidenceCount,
    checkoutDraft: checkoutDraft,
  );
}

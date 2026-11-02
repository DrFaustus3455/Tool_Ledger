class DamageRecord {
  const DamageRecord({
    required this.id,
    required this.assetId,
    required this.description,
    required this.reportedBy,
    required this.damageDate,
    required this.originalCostPkr,
    required this.accumulatedDepreciationPkr,
    required this.netBookValuePkr,
    required this.repairStatus,
    this.evidenceCount = 0,
  });
  final String id;
  final String assetId;
  final String description;
  final String reportedBy;
  final DateTime damageDate;
  final double originalCostPkr;
  final double accumulatedDepreciationPkr;
  final double netBookValuePkr;
  final String repairStatus;
  final int evidenceCount;
}

class DisposalRecord {
  const DisposalRecord({
    required this.assetId,
    required this.purchaseSummary,
    required this.disposalDate,
    required this.reason,
    required this.originalCostPkr,
    required this.accumulatedDepreciationPkr,
    required this.netBookValueAtDisposalPkr,
    required this.proceedsPkr,
    required this.authorizedBy,
    required this.transactionCount,
  });
  final String assetId;
  final String purchaseSummary;
  final DateTime disposalDate;
  final String reason;
  final double originalCostPkr;
  final double accumulatedDepreciationPkr;
  final double netBookValueAtDisposalPkr;
  final double proceedsPkr;
  final String authorizedBy;
  final int transactionCount;
}

const _unset = Object();

enum AssetStatus {
  available,
  checkedOut,
  overdue,
  missing,
  damaged,
  quarantined,
  underMaintenance,
  retired,
}

extension AssetStatusLabel on AssetStatus {
  String get label => switch (this) {
    AssetStatus.available => 'AVAILABLE',
    AssetStatus.checkedOut => 'CHECKED OUT',
    AssetStatus.overdue => 'OVERDUE',
    AssetStatus.missing => 'MISSING',
    AssetStatus.damaged => 'DAMAGED',
    AssetStatus.quarantined => 'QUARANTINED',
    AssetStatus.underMaintenance => 'UNDER MAINTENANCE',
    AssetStatus.retired => 'RETIRED',
  };
}

class ToolAsset {
  const ToolAsset({
    required this.id,
    required this.serialNumber,
    required this.description,
    required this.quantity,
    required this.partNumber,
    required this.series,
    required this.manufacturer,
    required this.equipmentType,
    required this.legacyTypePrimary,
    required this.legacyTypeSecondary,
    required this.legacyDepreciationPrimary,
    required this.legacyDepreciationSecondary,
    required this.unitPricePkr,
    required this.extendedPricePkr,
    required this.historicalGstAmountPkr,
    required this.historicalGstRate,
    required this.totalPurchaseValuePkr,
    required this.foreignCurrencyValue,
    required this.foreignCurrencyCode,
    required this.purchaseDate,
    required this.valuationDate,
    required this.usefulLifeYears,
    required this.residualValuePkr,
    required this.historicalAccumulatedDepreciationPkr,
    required this.vendor,
    required this.isImported,
    required this.oesPurchaseOrder,
    required this.billNumber,
    required this.billDate,
    required this.department,
    required this.lyingAt,
    required this.departmentCode,
    required this.condition,
    required this.issuedTo,
    required this.transferredTo,
    required this.purpose,
    required this.remarks,
    required this.lastUpdated,
    required this.currentBorrower,
    required this.expectedReturnDate,
    required this.status,
    required this.isRestricted,
    this.photoUrl,
  });

  final String id;
  final String serialNumber;
  final String description;
  final int quantity;
  final String partNumber;
  final String series;
  final String manufacturer;
  final String equipmentType;
  final String legacyTypePrimary;
  final String legacyTypeSecondary;
  final double legacyDepreciationPrimary;
  final double legacyDepreciationSecondary;
  final double unitPricePkr;
  final double extendedPricePkr;
  final double historicalGstAmountPkr;
  final double historicalGstRate;
  final double totalPurchaseValuePkr;
  final double foreignCurrencyValue;
  final String foreignCurrencyCode;
  final DateTime purchaseDate;
  final DateTime valuationDate;
  final int usefulLifeYears;
  final double residualValuePkr;
  final double historicalAccumulatedDepreciationPkr;
  final String vendor;
  final bool isImported;
  final String oesPurchaseOrder;
  final String billNumber;
  final DateTime billDate;
  final String department;
  final String lyingAt;
  final String departmentCode;
  final String condition;
  final String issuedTo;
  final String transferredTo;
  final String purpose;
  final String remarks;
  final DateTime lastUpdated;
  final String currentBorrower;
  final DateTime? expectedReturnDate;
  final AssetStatus status;
  final bool isRestricted;
  final String? photoUrl;

  int get daysSincePurchase =>
      valuationDate.difference(purchaseDate).inDays.clamp(0, 1000000);
  double get depreciableCost =>
      (totalPurchaseValuePkr - residualValuePkr).clamp(0, double.infinity);
  double get dailyDepreciation =>
      usefulLifeYears <= 0 ? 0 : depreciableCost / (usefulLifeYears * 365.0);
  double get accumulatedDepreciation =>
      (dailyDepreciation * daysSincePurchase).clamp(0, depreciableCost);
  double get netBookValue => (totalPurchaseValuePkr - accumulatedDepreciation)
      .clamp(residualValuePkr, totalPurchaseValuePkr);
  bool get financialReviewRequired =>
      (historicalAccumulatedDepreciationPkr - accumulatedDepreciation).abs() >
      totalPurchaseValuePkr * .08;
  bool get isLendable => status == AssetStatus.available;

  ToolAsset copyWith({
    AssetStatus? status,
    Object? currentBorrower = _unset,
    Object? expectedReturnDate = _unset,
    String? condition,
    String? lyingAt,
    DateTime? lastUpdated,
    Object? photoUrl = _unset,
  }) => ToolAsset(
    id: id,
    serialNumber: serialNumber,
    description: description,
    quantity: quantity,
    partNumber: partNumber,
    series: series,
    manufacturer: manufacturer,
    equipmentType: equipmentType,
    legacyTypePrimary: legacyTypePrimary,
    legacyTypeSecondary: legacyTypeSecondary,
    legacyDepreciationPrimary: legacyDepreciationPrimary,
    legacyDepreciationSecondary: legacyDepreciationSecondary,
    unitPricePkr: unitPricePkr,
    extendedPricePkr: extendedPricePkr,
    historicalGstAmountPkr: historicalGstAmountPkr,
    historicalGstRate: historicalGstRate,
    totalPurchaseValuePkr: totalPurchaseValuePkr,
    foreignCurrencyValue: foreignCurrencyValue,
    foreignCurrencyCode: foreignCurrencyCode,
    purchaseDate: purchaseDate,
    valuationDate: valuationDate,
    usefulLifeYears: usefulLifeYears,
    residualValuePkr: residualValuePkr,
    historicalAccumulatedDepreciationPkr: historicalAccumulatedDepreciationPkr,
    vendor: vendor,
    isImported: isImported,
    oesPurchaseOrder: oesPurchaseOrder,
    billNumber: billNumber,
    billDate: billDate,
    department: department,
    lyingAt: lyingAt ?? this.lyingAt,
    departmentCode: departmentCode,
    condition: condition ?? this.condition,
    issuedTo: issuedTo,
    transferredTo: transferredTo,
    purpose: purpose,
    remarks: remarks,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    currentBorrower: identical(currentBorrower, _unset)
        ? this.currentBorrower
        : currentBorrower as String,
    expectedReturnDate: identical(expectedReturnDate, _unset)
        ? this.expectedReturnDate
        : expectedReturnDate as DateTime?,
    status: status ?? this.status,
    isRestricted: isRestricted,
    photoUrl: identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
  );

  Map<String, dynamic> toJson() => {
    'assetId': id,
    'serialNumber': serialNumber,
    'description': description,
    'quantity': quantity,
    'partNumber': partNumber,
    'series': series,
    'manufacturer': manufacturer,
    'equipmentType': equipmentType,
    'legacyTypePrimary': legacyTypePrimary,
    'legacyTypeSecondary': legacyTypeSecondary,
    'legacyDepreciationPrimary': legacyDepreciationPrimary,
    'legacyDepreciationSecondary': legacyDepreciationSecondary,
    'unitPricePkr': unitPricePkr,
    'extendedPricePkr': extendedPricePkr,
    'historicalGstAmountPkr': historicalGstAmountPkr,
    'historicalGstRate': historicalGstRate,
    'totalPurchaseValuePkr': totalPurchaseValuePkr,
    'foreignCurrencyValue': foreignCurrencyValue,
    'foreignCurrencyCode': foreignCurrencyCode,
    'purchaseDate': purchaseDate.toIso8601String(),
    'valuationDate': valuationDate.toIso8601String(),
    'usefulLifeYears': usefulLifeYears,
    'residualValuePkr': residualValuePkr,
    'historicalAccumulatedDepreciationPkr':
        historicalAccumulatedDepreciationPkr,
    'vendor': vendor,
    'imported': isImported,
    'oesPurchaseOrder': oesPurchaseOrder,
    'billNumber': billNumber,
    'billDate': billDate.toIso8601String(),
    'department': department,
    'lyingAt': lyingAt,
    'departmentCode': departmentCode,
    'condition': condition,
    'issuedTo': issuedTo,
    'transferredTo': transferredTo,
    'purpose': purpose,
    'remarks': remarks,
    'lastUpdated': lastUpdated.toIso8601String(),
    'currentBorrower': currentBorrower,
    'expectedReturnDate': expectedReturnDate?.toIso8601String(),
    'status': status.name,
    'restricted': isRestricted,
    'photoUrl': photoUrl,
  };
}

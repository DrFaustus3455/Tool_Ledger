class DepreciationResult {
  const DepreciationResult({
    required this.daily,
    required this.accumulated,
    required this.netBookValue,
    required this.ageDays,
    required this.depreciableCost,
  });
  final double daily;
  final double accumulated;
  final double netBookValue;
  final int ageDays;
  final double depreciableCost;
}

class DepreciationCalculator {
  const DepreciationCalculator();
  DepreciationResult straightLine({
    required double purchaseCost,
    required double residualValue,
    required int usefulLifeYears,
    required DateTime purchaseDate,
    required DateTime valuationDate,
  }) {
    if (purchaseCost < 0 || residualValue < 0) {
      throw ArgumentError('Cost and residual value cannot be negative.');
    }
    if (residualValue > purchaseCost) {
      throw ArgumentError('Residual value cannot exceed purchase cost.');
    }
    if (usefulLifeYears < 1) {
      throw ArgumentError('Useful life must be at least one year.');
    }
    final ageDays = valuationDate
        .difference(purchaseDate)
        .inDays
        .clamp(0, 1000000);
    final depreciableCost = purchaseCost - residualValue;
    final daily = depreciableCost / (usefulLifeYears * 365.0);
    final accumulated = (daily * ageDays).clamp(0.0, depreciableCost);
    return DepreciationResult(
      daily: daily,
      accumulated: accumulated,
      netBookValue: purchaseCost - accumulated,
      ageDays: ageDays,
      depreciableCost: depreciableCost,
    );
  }
}

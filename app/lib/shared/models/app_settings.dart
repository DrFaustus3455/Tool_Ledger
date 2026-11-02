class AppSettings {
  const AppSettings({
    this.approvalThresholdPkr = 250000,
    this.defaultReturnDays = 7,
    this.defaultUsefulLifeYears = 5,
    this.restrictedCategories = const {'Precision Instruments'},
    this.conditionCategories = const {
      'Serviceable',
      'Needs inspection',
      'Damaged',
      'Quarantined',
    },
    this.lenderOperationalExport = true,
    this.overdueNotifications = true,
    this.approvalNotifications = true,
    this.dailyDigest = false,
  });
  final double approvalThresholdPkr;
  final int defaultReturnDays;
  final int defaultUsefulLifeYears;
  final Set<String> restrictedCategories;
  final Set<String> conditionCategories;
  final bool lenderOperationalExport;
  final bool overdueNotifications;
  final bool approvalNotifications;
  final bool dailyDigest;

  AppSettings copyWith({
    double? approvalThresholdPkr,
    int? defaultReturnDays,
    int? defaultUsefulLifeYears,
    Set<String>? restrictedCategories,
    Set<String>? conditionCategories,
    bool? lenderOperationalExport,
    bool? overdueNotifications,
    bool? approvalNotifications,
    bool? dailyDigest,
  }) => AppSettings(
    approvalThresholdPkr: approvalThresholdPkr ?? this.approvalThresholdPkr,
    defaultReturnDays: defaultReturnDays ?? this.defaultReturnDays,
    defaultUsefulLifeYears:
        defaultUsefulLifeYears ?? this.defaultUsefulLifeYears,
    restrictedCategories: restrictedCategories ?? this.restrictedCategories,
    conditionCategories: conditionCategories ?? this.conditionCategories,
    lenderOperationalExport:
        lenderOperationalExport ?? this.lenderOperationalExport,
    overdueNotifications: overdueNotifications ?? this.overdueNotifications,
    approvalNotifications: approvalNotifications ?? this.approvalNotifications,
    dailyDigest: dailyDigest ?? this.dailyDigest,
  );
}

enum LoanStatus { active, overdue, returned, pendingAuthorization }

class LoanRecord {
  const LoanRecord({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.borrowerName,
    required this.borrowerEmployeeId,
    required this.department,
    required this.workOrder,
    required this.purpose,
    required this.issuedBy,
    required this.issueDate,
    required this.dueDate,
    required this.status,
    this.returnDate,
    this.returnCondition,
    this.approvalId,
  });

  final String id;
  final String assetId;
  final String assetName;
  final String borrowerName;
  final String borrowerEmployeeId;
  final String department;
  final String workOrder;
  final String purpose;
  final String issuedBy;
  final DateTime issueDate;
  final DateTime dueDate;
  final LoanStatus status;
  final DateTime? returnDate;
  final String? returnCondition;
  final String? approvalId;

  LoanRecord copyWith({
    LoanStatus? status,
    DateTime? returnDate,
    String? returnCondition,
  }) => LoanRecord(
    id: id,
    assetId: assetId,
    assetName: assetName,
    borrowerName: borrowerName,
    borrowerEmployeeId: borrowerEmployeeId,
    department: department,
    workOrder: workOrder,
    purpose: purpose,
    issuedBy: issuedBy,
    issueDate: issueDate,
    dueDate: dueDate,
    status: status ?? this.status,
    returnDate: returnDate ?? this.returnDate,
    returnCondition: returnCondition ?? this.returnCondition,
    approvalId: approvalId,
  );

  Map<String, dynamic> toJson() => {
    'loanId': id,
    'assetId': assetId,
    'assetName': assetName,
    'borrowerName': borrowerName,
    'borrowerEmployeeId': borrowerEmployeeId,
    'department': department,
    'workOrder': workOrder,
    'purpose': purpose,
    'issuedBy': issuedBy,
    'issueDate': issueDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'status': status.name,
    'returnDate': returnDate?.toIso8601String(),
    'returnCondition': returnCondition,
    'approvalId': approvalId,
  };
}

class CheckoutDraft {
  const CheckoutDraft({
    required this.assetId,
    required this.borrowerName,
    required this.borrowerEmployeeId,
    required this.department,
    required this.workOrder,
    required this.purpose,
    required this.dueDate,
  });
  final String assetId;
  final String borrowerName;
  final String borrowerEmployeeId;
  final String department;
  final String workOrder;
  final String purpose;
  final DateTime dueDate;
}

enum CheckoutResult { checkedOut, approvalRequired }

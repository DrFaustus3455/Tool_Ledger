class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.actor,
    required this.action,
    required this.recordId,
    required this.timestamp,
    required this.details,
    required this.category,
  });
  final String id;
  final String actor;
  final String action;
  final String recordId;
  final DateTime timestamp;
  final String details;
  final String category;
}

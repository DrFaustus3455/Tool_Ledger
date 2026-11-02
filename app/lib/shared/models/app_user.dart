enum UserRole {
  manager,
  lender;

  /// Strict server-role parser. Unknown roles return null so callers can
  /// reject the session instead of silently granting a default role.
  static UserRole? tryParse(String? value) =>
      switch (value?.trim().toUpperCase()) {
        'MANAGER' => UserRole.manager,
        'LENDER' => UserRole.lender,
        _ => null,
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.employeeId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.department,
    this.isActive = true,
    this.lastLogin,
    this.activeSessions = 1,
  });
  final String id;
  final String employeeId;
  final String username;
  final String displayName;
  final UserRole role;
  final String department;
  final bool isActive;
  final DateTime? lastLogin;
  final int activeSessions;

  AppUser copyWith({
    bool? isActive,
    DateTime? lastLogin,
    int? activeSessions,
  }) => AppUser(
    id: id,
    employeeId: employeeId,
    username: username,
    displayName: displayName,
    role: role,
    department: department,
    isActive: isActive ?? this.isActive,
    lastLogin: lastLogin ?? this.lastLogin,
    activeSessions: activeSessions ?? this.activeSessions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'username': username,
    'displayName': displayName,
    'role': role.name.toUpperCase(),
    'department': department,
    'active': isActive,
    'lastLogin': lastLogin?.toIso8601String(),
    'activeSessions': activeSessions,
  };
}

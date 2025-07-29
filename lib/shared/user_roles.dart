// lib/shared/user_role.dart

enum UserRole {
  user,
  member,
  groupAdmin,
  nurseryStaff,
  leader,
  supervisor,
  owner,
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.member:
        return 'member';
      case UserRole.groupAdmin:
        return 'group_admin';
      case UserRole.nurseryStaff:
        return 'nursery_staff';
      case UserRole.leader:
        return 'leader';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.owner:
        return 'owner';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'supervisor':
        return UserRole.supervisor;
      case 'leader':
        return UserRole.leader;
      case 'nursery_staff':
        return UserRole.nurseryStaff;
      case 'group_admin':
        return UserRole.groupAdmin;
      case 'member':
        return UserRole.member;
      case 'user':
      default:
        return UserRole.user;
    }
  }
}
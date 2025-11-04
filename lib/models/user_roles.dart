enum UserRoles {
  admin,
  manager,
  support,
  client,
  freelancer,
  seller,
}

const UserRoles kDefaultUserRole = UserRoles.client;
const String kDefaultUserRoleName = 'client';

const Set<UserRoles> kAllUserRoles = {
  UserRoles.admin,
  UserRoles.manager,
  UserRoles.support,
  UserRoles.client,
  UserRoles.freelancer,
  UserRoles.seller,
};

const Set<String> kAllUserRoleNames = {
  'admin',
  'manager',
  'support',
  'client',
  'freelancer',
  'seller',
};

extension UserRolesX on UserRoles {
  String get value => name;
}

UserRoles parseUserRole(String? value) {
  if (value == null) {
    return kDefaultUserRole;
  }
  final normalized = value.trim().toLowerCase();
  for (final role in UserRoles.values) {
    if (role.name == normalized) {
      return role;
    }
  }
  return kDefaultUserRole;
}

String ensureUserRoleName(String? value) {
  return parseUserRole(value).name;
}

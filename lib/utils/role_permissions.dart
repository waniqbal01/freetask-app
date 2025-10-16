/// Centralized role identifiers used throughout the app.
class UserRoles {
  const UserRoles._();

  static const client = 'client';
  static const freelancer = 'freelancer';
  static const admin = 'admin';
  static const manager = 'manager';
  static const support = 'support';

  static const defaultRole = client;

  static const all = <String>{
    client,
    freelancer,
    admin,
    manager,
    support,
  };
}

/// High level permission identifiers representing role based capabilities.
enum RolePermission {
  viewDashboard,
  manageUsers,
  viewJobs,
  viewOwnJobs,
  createJob,
  acceptJob,
  completeJob,
  payJob,
  viewChats,
}

class RolePermissionConfig {
  const RolePermissionConfig({
    required this.allowedRoles,
    required this.description,
    this.requiresAuth = true,
  });

  final Set<String> allowedRoles;
  final String description;
  final bool requiresAuth;

  bool isAllowed(String? role) => role != null && allowedRoles.contains(role);
}

/// Provides a single source of truth for role permissions.
class RolePermissions {
  static final Map<RolePermission, RolePermissionConfig> _configs = {
    RolePermission.viewDashboard: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
        UserRoles.admin,
        UserRoles.manager,
        UserRoles.support,
      },
      description: 'view dashboards',
    ),
    RolePermission.manageUsers: RolePermissionConfig(
      allowedRoles: {
        UserRoles.admin,
        UserRoles.manager,
        UserRoles.support,
      },
      description: 'manage users',
    ),
    RolePermission.viewJobs: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
        UserRoles.admin,
        UserRoles.manager,
        UserRoles.support,
      },
      description: 'browse jobs',
    ),
    RolePermission.viewOwnJobs: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
      },
      description: 'view personal jobs',
    ),
    RolePermission.createJob: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
      },
      description: 'create jobs',
    ),
    RolePermission.acceptJob: RolePermissionConfig(
      allowedRoles: {
        UserRoles.freelancer,
      },
      description: 'accept jobs',
    ),
    RolePermission.completeJob: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
      },
      description: 'mark jobs as complete',
    ),
    RolePermission.payJob: RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
      },
      description: 'pay for jobs',
    ),
    RolePermission.viewChats: RolePermissionConfig(
      allowedRoles: RolePermission.viewJobs.allowedRoles,
      description: 'access chats',
    ),
  };

  static RolePermissionConfig config(RolePermission permission) {
    return _configs[permission] ??
        const RolePermissionConfig(
          allowedRoles: {},
          description: 'perform this action',
        );
  }

  static Set<String> allowedRoles(RolePermission permission) {
    return config(permission).allowedRoles;
  }

  static bool isAllowed(String? role, RolePermission permission) {
    return config(permission).isAllowed(role);
  }

  static String describe(RolePermission permission) {
    return config(permission).description;
  }

  static bool requiresAuth(RolePermission permission) {
    return config(permission).requiresAuth;
  }

  /// Allows overriding permissions at runtime for future expansion if needed.
  static void register(
    RolePermission permission,
    RolePermissionConfig config,
  ) {
    _configs[permission] = config;
  }
}

extension on RolePermission {
  Set<String> get allowedRoles => RolePermissions.allowedRoles(this);
}

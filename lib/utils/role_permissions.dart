/// Centralized role identifiers used throughout the app.
class UserRoles {
  const UserRoles._();

  static const client = 'client';
  static const freelancer = 'freelancer';
  static const admin = 'admin';

  static const defaultRole = client;

  static const all = <String>{
    client,
    freelancer,
    admin,
  };
}

/// High level permission identifiers representing role based capabilities.
enum RolePermission {
  viewMarketplace,
  viewServiceDetail,
  purchaseServices,
  checkoutService,
  viewOrders,
  manageBuyerOrders,
  manageSellerOrders,
  manageOwnServices,
  accessSellerDashboard,
  accessAdminConsole,
  moderateServices,
  manageTransactions,
  managePayouts,
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

/// Provides a single source of truth for role permissions across the
/// marketplace experience.
class RolePermissions {
  static final Map<RolePermission, RolePermissionConfig> _configs = {
    RolePermission.viewMarketplace: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'browse marketplace services',
      requiresAuth: false,
    ),
    RolePermission.viewServiceDetail: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'view detailed service information',
      requiresAuth: false,
    ),
    RolePermission.purchaseServices: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
      },
      description: 'purchase services from freelancers',
    ),
    RolePermission.checkoutService: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
      },
      description: 'complete service checkout',
    ),
    RolePermission.viewOrders: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'view marketplace orders',
    ),
    RolePermission.manageBuyerOrders: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.client,
        UserRoles.admin,
      },
      description: 'manage purchased orders',
    ),
    RolePermission.manageSellerOrders: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'manage sold orders',
    ),
    RolePermission.manageOwnServices: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'create and update services',
    ),
    RolePermission.accessSellerDashboard: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.freelancer,
        UserRoles.admin,
      },
      description: 'access seller dashboard',
    ),
    RolePermission.accessAdminConsole: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.admin,
      },
      description: 'access administrative console',
    ),
    RolePermission.moderateServices: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.admin,
      },
      description: 'moderate marketplace services',
    ),
    RolePermission.manageTransactions: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.admin,
      },
      description: 'manage escrow transactions',
    ),
    RolePermission.managePayouts: const RolePermissionConfig(
      allowedRoles: {
        UserRoles.admin,
      },
      description: 'release freelancer payouts',
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

  static bool roleCanCreateService(String? role) {
    return isAllowed(role, RolePermission.manageOwnServices);
  }

  static bool roleCanCheckout(String? role) {
    return isAllowed(role, RolePermission.checkoutService);
  }

  static bool roleCanAccessSellerDashboard(String? role) {
    return isAllowed(role, RolePermission.accessSellerDashboard);
  }

  static bool roleCanAccessAdmin(String? role) {
    return isAllowed(role, RolePermission.accessAdminConsole);
  }

  static bool roleCanManageOrders(String? role) {
    return isAllowed(role, RolePermission.manageBuyerOrders) ||
        isAllowed(role, RolePermission.manageSellerOrders);
  }
}

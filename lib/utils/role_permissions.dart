import '../auth/role_permission.dart';
import '../models/user_roles.dart';

class RolePermissionConfig {
  const RolePermissionConfig({
    required Set<UserRoles> allowedRoles,
    required this.description,
    this.requiresAuth = true,
  }) : _allowedRoles = allowedRoles;

  final Set<UserRoles> _allowedRoles;
  final String description;
  final bool requiresAuth;

  Set<UserRoles> get allowedUserRoles => _allowedRoles;

  Set<String> get allowedRoles => {
        for (final role in _allowedRoles) role.name,
      };

  bool isAllowed(String? role) {
    if (role == null) {
      return false;
    }
    final parsed = parseUserRole(role);
    return _allowedRoles.contains(parsed);
  }
}

class RolePermissions {
  static final Map<RolePermission, String> _descriptions = {
    RolePermission.viewMarketplace: 'browse marketplace services',
    RolePermission.viewServiceDetail: 'view detailed service information',
    RolePermission.purchaseServices: 'purchase services from freelancers',
    RolePermission.checkoutService: 'complete service checkout',
    RolePermission.viewOrders: 'view marketplace orders',
    RolePermission.manageBuyerOrders: 'manage purchased orders',
    RolePermission.manageSellerOrders: 'manage sold orders',
    RolePermission.manageOwnServices: 'create and update services',
    RolePermission.accessSellerDashboard: 'access seller dashboard',
    RolePermission.accessAdminConsole: 'access administrative console',
    RolePermission.moderateServices: 'moderate marketplace services',
    RolePermission.manageTransactions: 'manage escrow transactions',
    RolePermission.managePayouts: 'release freelancer payouts',
    RolePermission.viewDashboard: 'view dashboards',
    RolePermission.viewBids: 'view bids',
    RolePermission.manageBids: 'manage bids',
    RolePermission.viewChats: 'access chat conversations',
    RolePermission.viewOwnJobs: 'view personal jobs',
    RolePermission.viewJobs: 'browse available jobs',
    RolePermission.createJob: 'create jobs',
    RolePermission.acceptJob: 'accept jobs',
    RolePermission.completeJob: 'complete jobs',
    RolePermission.cancelJob: 'cancel jobs',
    RolePermission.payJob: 'pay for jobs',
    RolePermission.viewNotifications: 'view notifications',
    RolePermission.viewWallet: 'view wallet balance',
    RolePermission.releasePayment: 'release payments to freelancers',
  };

  static final Map<RolePermission, bool> _requiresAuthOverrides = {
    RolePermission.viewMarketplace: false,
    RolePermission.viewServiceDetail: false,
  };

  static RolePermissionConfig config(RolePermission permission) {
    final allowed = allowedUserRoles(permission);
    final description = _descriptions[permission] ?? 'perform this action';
    final requiresAuth = _requiresAuthOverrides[permission] ?? true;
    return RolePermissionConfig(
      allowedRoles: allowed,
      description: description,
      requiresAuth: requiresAuth,
    );
  }

  static Set<UserRoles> allowedUserRoles(RolePermission permission) {
    return {
      for (final entry in kRolePermissions.entries)
        if (entry.value.contains(permission)) entry.key,
    };
  }

  static Set<String> allowedRoles(RolePermission permission) {
    return config(permission).allowedRoles;
  }

  static bool isAllowed(String? role, RolePermission permission) {
    if (role == null) {
      return false;
    }
    final parsed = parseUserRole(role);
    return allowedUserRoles(permission).contains(parsed);
  }

  static String describe(RolePermission permission) {
    return _descriptions[permission] ?? 'perform this action';
  }

  static bool requiresAuth(RolePermission permission) {
    return _requiresAuthOverrides[permission] ?? true;
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

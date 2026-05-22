import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';

/// Auth middleware for GetX route guard.
///
/// Redirects to Login if:
/// - No token is stored
/// - Token is expired (and refresh fails)
///
/// This runs BEFORE the route is built, preventing
/// any flash of protected content.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final authController = Get.find<AuthController>();

    // If not authenticated, redirect to login
    if (!authController.isAuthenticated.value) {
      return const RouteSettings(name: '/login');
    }

    // If token is expired, redirect to login
    if (authController.currentUser.value?.isTokenExpired == true) {
      return const RouteSettings(name: '/login');
    }

    return null; // Allow navigation
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';

/// Splash screen shown on cold start.
///
/// Handles:
/// 1. Reading stored token from secure storage
/// 2. Silent token refresh if expired
/// 3. Navigation to Login or Home based on auth state
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    void navigate() {
      if (authController.isAuthenticated.value) {
        Get.offAllNamed('/home');
      } else {
        Get.offAllNamed('/login');
      }
    }

    // If already initialized, navigate immediately after the frame
    if (!authController.isInitializing.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
    } else {
      // Otherwise listen for the state change when initialization finishes
      ever(authController.isInitializing, (bool initializing) {
        if (!initializing) {
          navigate();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // App name
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Text(
                'Task Manager',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Text(
                'Organize • Prioritize • Deliver',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 2,
                    ),
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

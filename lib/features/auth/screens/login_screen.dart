import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';

/// Login screen with email + password fields and form validation.
///
/// Uses GetX for:
/// - Form state management
/// - Error message display
/// - Loading indicator
///
/// Design: Premium dark theme with glassmorphism card,
/// gradient button, and smooth animations.
class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ─── Logo & Welcome ──────────────────────────────
                _buildLogo(),
                const SizedBox(height: 16),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),

                const SizedBox(height: 40),

                // ─── Login Form ──────────────────────────────────
                _buildLoginForm(context, authController),

                const Spacer(flex: 3),

                // ─── Register Link ───────────────────────────────────
                _buildRegisterLink(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.task_alt_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthController authController) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: authController.validateEmail,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppTheme.primaryColor,
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
              ),
            ),

            const SizedBox(height: 16),

            // Password field
            _PasswordField(
              controller: _passwordController,
              validator: authController.validatePassword,
            ),

            const SizedBox(height: 8),

            // Error message
            Obx(() {
              if (authController.errorMessage.value.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.errorColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authController.errorMessage.value,
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 24),

            // Login button
            Obx(() {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 52,
                child: ElevatedButton(
                  onPressed: authController.isLoading.value
                      ? null
                      : () => _handleLogin(authController),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: authController.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/register'),
          child: const Text(
            'Register',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogin(AuthController authController) async {
    if (_formKey.currentState!.validate()) {
      final success = await authController.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        Get.offAllNamed('/home');
      }
    }
  }
}

/// Password field with visibility toggle.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: '••••••',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppTheme.primaryColor,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppTheme.textMuted,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: AppTheme.cardColor,
      ),
    );
  }
}

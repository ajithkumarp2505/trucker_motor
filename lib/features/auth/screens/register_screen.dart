import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';

/// Register screen with name, email + password fields and form validation.
class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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

                // ─── Header ──────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: () => Get.back(),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),

                const SizedBox(height: 40),

                // ─── Register Form ──────────────────────────────────
                _buildRegisterForm(context, authController),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context, AuthController authController) {
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
            // Name field
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              validator: authController.validateName,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'John Doe',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.primaryColor,
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
              ),
            ),

            const SizedBox(height: 16),

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

            // Register button
            Obx(() {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 52,
                child: ElevatedButton(
                  onPressed: authController.isLoading.value
                      ? null
                      : () => _handleRegister(authController),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Register',
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

  void _handleRegister(AuthController authController) async {
    if (_formKey.currentState!.validate()) {
      final success = await authController.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        await authController.logout();
        Get.offAllNamed('/login');
        
        Get.snackbar(
          'Registration Successful',
          'Please login with your new credentials.',
          backgroundColor: AppTheme.doneStatus.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
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

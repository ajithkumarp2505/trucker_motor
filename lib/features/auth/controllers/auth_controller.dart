import 'dart:async';
import 'package:get/get.dart';
import 'package:trucker_motor/features/auth/models/user_model.dart';
import 'package:trucker_motor/features/auth/repositories/auth_repository.dart';

class AuthController extends GetxController {
  final AuthRepository _authRepository;

  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isAuthenticated = false.obs;

  Completer<bool>? _refreshCompleter;

  @override
  void onInit() {
    super.onInit();
    _initializeAuth();
  }

  @override
  void onClose() {
    currentUser.close();
    isLoading.close();
    isInitializing.close();
    errorMessage.close();
    isAuthenticated.close();
    super.onClose();
  }

  Future<void> _initializeAuth() async {
    try {
      final result = await _authRepository.getStoredUser();

      result.fold(
        (failure) {
          isAuthenticated.value = false;
          isInitializing.value = false;
        },
        (user) async {
          if (user.isTokenExpired) {
            final refreshed = await _silentRefresh();
            if (!refreshed) {
              isAuthenticated.value = false;
              isInitializing.value = false;
              return;
            }
          } else {
            currentUser.value = user;
            isAuthenticated.value = true;
          }
          isInitializing.value = false;
        },
      );
    } catch (e) {
      isAuthenticated.value = false;
      isInitializing.value = false;
    }
  }

  Future<bool> login(String email, String password) async {
    errorMessage.value = '';
    isLoading.value = true;

    try {
      final result = await _authRepository.login(email, password);

      return result.fold(
        (failure) {
          errorMessage.value = failure.message;
          isLoading.value = false;
          return false;
        },
        (user) {
          currentUser.value = user;
          isAuthenticated.value = true;
          isLoading.value = false;
          return true;
        },
      );
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
      isLoading.value = false;
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    errorMessage.value = '';
    isLoading.value = true;

    try {
      final result = await _authRepository.register(name, email, password);

      return result.fold(
        (failure) {
          errorMessage.value = failure.message;
          isLoading.value = false;
          return false;
        },
        (user) {
          currentUser.value = user;
          isAuthenticated.value = true;
          isLoading.value = false;
          return true;
        },
      );
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
      isLoading.value = false;
      return false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;

    await _authRepository.logout();

    currentUser.value = null;
    isAuthenticated.value = false;
    isLoading.value = false;

    Get.offAllNamed('/login');
  }

  Future<bool> _silentRefresh() async {
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final result = await _authRepository.refreshToken();

      final success = result.fold(
        (failure) {
          currentUser.value = null;
          isAuthenticated.value = false;
          return false;
        },
        (user) {
          currentUser.value = user;
          isAuthenticated.value = true;
          return true;
        },
      );

      _refreshCompleter!.complete(success);
      return success;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Public method for the interceptor to call when 401 is received.
  Future<bool> refreshToken() async {
    return await _silentRefresh();
  }

  // ─── Validation ────────────────────────────────────────────────

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}

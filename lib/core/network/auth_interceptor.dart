import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:trucker_motor/core/services/storage_service.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';


class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final StorageService _storageService;


  Completer<bool>? _refreshLock;

  bool _isRetrying = false;

  AuthInterceptor({
    required Dio dio,
    required StorageService storageService,
  })  : _dio = dio,
        _storageService = storageService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    
    options.extra['requestTimestamp'] = DateTime.now().toIso8601String();

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
  
    if (err.response?.statusCode == 401 && !_isRetrying) {
      try {
        final refreshed = await _handleTokenRefresh();

        if (refreshed) {
          
          _isRetrying = true;
          final token = await _storageService.getToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';

          try {
            final response = await _dio.fetch(opts);
            _isRetrying = false;
            return handler.resolve(response);
          } catch (e) {
            _isRetrying = false;
            return handler.next(err);
          }
        } else {
          _triggerLogout();
          return handler.next(err);
        }
      } catch (e) {
        _triggerLogout();
        return handler.next(err);
      }
    }

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      return handler.next(err);
    }

    final timestamp = err.requestOptions.extra['requestTimestamp'] ?? 'unknown';
    // ignore: avoid_print
    print(
        '[API Error] ${err.response?.statusCode} - ${err.requestOptions.path} - $timestamp');

    handler.next(err);
  }

  /// Handle token refresh with a lock mechanism.
  ///
  /// If 3 concurrent API calls all receive 401 simultaneously,
  /// only the FIRST triggers a refresh. The other 2 await the
  /// same Completer.
  Future<bool> _handleTokenRefresh() async {
    // If refresh is already in progress, wait for it
    if (_refreshLock != null) {
      return await _refreshLock!.future;
    }

    _refreshLock = Completer<bool>();

    try {
      // Use the AuthController to refresh the token
      if (getx.Get.isRegistered<AuthController>()) {
        final authController = getx.Get.find<AuthController>();
        final success = await authController.refreshToken();
        _refreshLock!.complete(success);
        return success;
      }

      _refreshLock!.complete(false);
      return false;
    } catch (e) {
      _refreshLock!.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  void _triggerLogout() {
    if (getx.Get.isRegistered<AuthController>()) {
      final authController = getx.Get.find<AuthController>();
      authController.logout();
    }
  }
}

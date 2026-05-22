import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:trucker_motor/core/constants/api_constants.dart';
import 'package:trucker_motor/core/network/auth_interceptor.dart';
import 'package:trucker_motor/core/services/storage_service.dart';


class ApiClient {
  late final Dio dio;
  final StorageService _storageService;

  ApiClient({required StorageService storageService})
      : _storageService = storageService {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        storageService: _storageService,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        logPrint: (o) => debugPrint('[DIO] $o'),
      ),
    );
  }
}

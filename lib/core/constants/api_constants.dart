class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static const String todosEndpoint = '/todos';
  static const String loginEndpoint = '/users'; // mock login
  static const String usersEndpoint = '/users';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int maxRetries = 2;
  static const Duration retryBaseDelay = Duration(seconds: 2);

  static const Duration searchDebounce = Duration(milliseconds: 300);

  static const Duration syncInterval = Duration(minutes: 15);

  static const Duration undoDeleteDuration = Duration(seconds: 5);
}

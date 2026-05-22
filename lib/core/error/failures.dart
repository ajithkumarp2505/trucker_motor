import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Session expired. Please login again.',
  ]) : super(statusCode: 401);
}

class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Failed to parse server response.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to access local cache.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}

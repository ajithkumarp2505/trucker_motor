import 'package:dartz/dartz.dart';
import 'package:trucker_motor/core/error/failures.dart';
import 'package:trucker_motor/features/auth/models/user_model.dart';

/// Abstract auth repository — defines the contract.
///
/// Following the Repository pattern: the controller/BLoC only
/// depends on this interface, never on the concrete implementation.
abstract class AuthRepository {
  /// Authenticate user with email and password.
  Future<Either<Failure, UserModel>> login(String email, String password);

  /// Register user with name, email and password.
  Future<Either<Failure, UserModel>> register(String name, String email, String password);

  /// Refresh an expired token.
  Future<Either<Failure, UserModel>> refreshToken();

  /// Logout the current user.
  Future<Either<Failure, void>> logout();

  /// Get stored user data (cold start).
  Future<Either<Failure, UserModel>> getStoredUser();
}

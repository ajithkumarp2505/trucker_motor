import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trucker_motor/core/error/failures.dart';
import 'package:trucker_motor/core/services/storage_service.dart';
import 'package:trucker_motor/features/auth/models/user_model.dart';
import 'package:trucker_motor/features/auth/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository].
///
/// Uses Firebase Authentication for login and registration.
class AuthRepositoryImpl implements AuthRepository {
  final StorageService _storageService;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AuthRepositoryImpl({
    required Dio dio,
    required StorageService storageService,
  }) : _storageService = storageService;

  @override
  Future<Either<Failure, UserModel>> login(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return const Left(ServerFailure('Login failed. No user returned.'));
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        return const Left(ServerFailure('Login failed. No token returned.'));
      }

      final tokenExpiry = DateTime.now().add(const Duration(hours: 1)); // approximate

      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? email,
        name: user.displayName ?? '',
        token: idToken,
        tokenExpiry: tokenExpiry,
      );

      // Store credentials securely
      await _storageService.saveAuthData(
        token: userModel.token,
        tokenExpiry: userModel.tokenExpiry,
        userId: userModel.id,
        email: userModel.email,
      );

      return Right(userModel);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return const Left(ServerFailure('Invalid email or password.'));
      } else if (e.code == 'network-request-failed') {
        return const Left(NetworkFailure());
      }
      return Left(ServerFailure(e.message ?? 'Authentication failed.'));
    } catch (e) {
      return Left(UnknownFailure('Login failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return const Left(ServerFailure('Registration failed. No user returned.'));
      }

      // Update display name
      await user.updateDisplayName(name);

      final idToken = await user.getIdToken();
      if (idToken == null) {
        return const Left(ServerFailure('Registration failed. No token returned.'));
      }

      final tokenExpiry = DateTime.now().add(const Duration(hours: 1)); // approximate

      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? email,
        name: name,
        token: idToken,
        tokenExpiry: tokenExpiry,
      );

      // Store credentials securely
      await _storageService.saveAuthData(
        token: userModel.token,
        tokenExpiry: userModel.tokenExpiry,
        userId: userModel.id,
        email: userModel.email,
      );

      return Right(userModel);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return const Left(ServerFailure('The account already exists for that email.'));
      } else if (e.code == 'weak-password') {
        return const Left(ServerFailure('The password provided is too weak.'));
      } else if (e.code == 'network-request-failed') {
        return const Left(NetworkFailure());
      }
      return Left(ServerFailure(e.message ?? 'Registration failed.'));
    } catch (e) {
      return Left(UnknownFailure('Registration failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> refreshToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Left(UnauthorizedFailure('No active user session.'));
      }

      final idToken = await user.getIdToken(true); // force refresh
      if (idToken == null) {
        return const Left(UnauthorizedFailure('Could not refresh token.'));
      }

      final newExpiry = DateTime.now().add(const Duration(hours: 1));

      await _storageService.saveToken(idToken);
      await _storageService.saveTokenExpiry(newExpiry);

      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? '',
        token: idToken,
        tokenExpiry: newExpiry,
      );

      return Right(userModel);
    } catch (e) {
      return Left(UnknownFailure('Token refresh failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _firebaseAuth.signOut();
      await _storageService.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getStoredUser() async {
    try {
      // With firebase auth, we can just check currentUser
      // But we also check secure storage for token to maintain the local flow
      final token = await _storageService.getToken();
      final expiry = await _storageService.getTokenExpiry();
      final userId = await _storageService.getUserId();
      final email = await _storageService.getUserEmail();

      final firebaseUser = _firebaseAuth.currentUser;

      if (token == null || expiry == null || userId == null || email == null || firebaseUser == null) {
        return const Left(UnauthorizedFailure('No stored session found.'));
      }

      final user = UserModel(
        id: userId,
        email: email,
        name: firebaseUser.displayName ?? '',
        token: token,
        tokenExpiry: expiry,
      );

      return Right(user);
    } catch (e) {
      return Left(CacheFailure('Failed to read stored user: ${e.toString()}'));
    }
  }
}

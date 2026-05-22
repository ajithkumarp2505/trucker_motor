import 'package:equatable/equatable.dart';

/// User model for authentication.
///
/// Stores user identity and token information.
/// The [isTokenExpired] getter is the single source of truth
/// for whether the current session is valid.
class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String token;
  final DateTime tokenExpiry;

  const UserModel({
    required this.id,
    required this.email,
    this.name = '',
    required this.token,
    required this.tokenExpiry,
  });

  /// Check if the stored token has expired.
  bool get isTokenExpired => DateTime.now().isAfter(tokenExpiry);

  /// Create from JSON response.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      token: json['token'] ?? '',
      tokenExpiry: json['tokenExpiry'] != null
          ? DateTime.parse(json['tokenExpiry'])
          : DateTime.now().add(const Duration(hours: 1)),
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'token': token,
      'tokenExpiry': tokenExpiry.toIso8601String(),
    };
  }

  /// Create a copy with updated fields.
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? token,
    DateTime? tokenExpiry,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      token: token ?? this.token,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }

  @override
  List<Object?> get props => [id, email, name, token, tokenExpiry];
}

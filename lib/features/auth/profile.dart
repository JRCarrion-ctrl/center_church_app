// lib/auth/profile.dart
class Profile {
  final String id;
  final String displayName;
  final String? email;
  final String role;

  Profile({
    required this.id,
    this.displayName = '',
    this.email,
    this.role = '',
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] ?? '',
      email: map['email'],
      role: map['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'role': role,
    };
  }
}


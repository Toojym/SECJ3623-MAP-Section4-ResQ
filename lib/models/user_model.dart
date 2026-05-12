import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String role;
  final String displayName;
  final DateTime createdAt;
  final bool profileComplete;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
    required this.createdAt,
    required this.profileComplete,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'citizen',
      displayName: data['displayName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileComplete: data['profileComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileComplete': profileComplete,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? displayName,
    DateTime? createdAt,
    bool? profileComplete,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }

  @override
  List<Object?> get props => [uid, email, role, displayName, createdAt, profileComplete];
}

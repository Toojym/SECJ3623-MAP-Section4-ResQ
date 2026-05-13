class VolunteerProfileModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String skills;
  final String location;
  final String? profileImageUrl;
  final bool isActive;
  final int sigapMataPoints;

  const VolunteerProfileModel({
    required this.uid,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.skills = '',
    this.location = '',
    this.profileImageUrl,
    this.isActive = false,
    this.sigapMataPoints = 0,
  });

  factory VolunteerProfileModel.fromMap(String uid, Map<String, dynamic> map) {
    return VolunteerProfileModel(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      skills: map['skills'] as String? ?? '',
      location: map['location'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
      isActive: map['isActive'] as bool? ?? false,
      sigapMataPoints: map['sigapMataPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'skills': skills,
        'location': location,
        'profileImageUrl': profileImageUrl,
        'isActive': isActive,
        'sigapMataPoints': sigapMataPoints,
      };

  VolunteerProfileModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    String? skills,
    String? location,
    String? profileImageUrl,
    bool? isActive,
    int? sigapMataPoints,
  }) {
    return VolunteerProfileModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      skills: skills ?? this.skills,
      location: location ?? this.location,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      sigapMataPoints: sigapMataPoints ?? this.sigapMataPoints,
    );
  }
}
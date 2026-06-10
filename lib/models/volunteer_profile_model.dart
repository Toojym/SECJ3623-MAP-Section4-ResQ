// Update VolunteerProfileModel (volunteer_profile_model.dart)
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
  final double? currentLat;
  final double? currentLng;
  final String assignedSquad;
  final String assignedSquadId;

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
    this.currentLat,
    this.currentLng,
    this.assignedSquad = '',
    this.assignedSquadId = '',
  });

  factory VolunteerProfileModel.fromMap(String uid, Map<String, dynamic> map) {
    return VolunteerProfileModel(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      skills: (map['skills'] is List)
          ? (map['skills'] as List).join(', ')
          : map['skills'] as String? ?? '',
      location: map['location'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
      isActive: map['isActive'] as bool? ?? false,
      sigapMataPoints: map['sigapMataPoints'] as int? ?? 0,
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      assignedSquad: map['assignedSquad'] as String? ?? '',
      assignedSquadId: map['assignedSquadId'] as String? ?? '',
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
        'currentLat': currentLat,
        'currentLng': currentLng,
        'assignedSquad': assignedSquad,
        'assignedSquadId': assignedSquadId,
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
    double? currentLat,
    double? currentLng,
    String? assignedSquad,
    String? assignedSquadId,
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
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      assignedSquad: assignedSquad ?? this.assignedSquad,
      assignedSquadId: assignedSquadId ?? this.assignedSquadId,
    );
  }
}
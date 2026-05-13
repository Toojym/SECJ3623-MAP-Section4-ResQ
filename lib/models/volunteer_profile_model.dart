import 'package:equatable/equatable.dart';

class VolunteerProfileModel extends Equatable {
  final String uid;
  final List<String> skills;
  final String availabilityStart;
  final String availabilityEnd;
  final bool isActive;
  final int sigapMataPoints;
  final List<String> certifications;

  const VolunteerProfileModel({
    required this.uid,
    required this.skills,
    required this.availabilityStart,
    required this.availabilityEnd,
    required this.isActive,
    required this.sigapMataPoints,
    required this.certifications,
  });

  factory VolunteerProfileModel.fromFirestore(Map<String, dynamic> data) {
    return VolunteerProfileModel(
      uid: data['uid'] as String? ?? '',
      skills: List<String>.from(data['skills'] as List? ?? []),
      availabilityStart: data['availabilityStart'] as String? ?? '08:00',
      availabilityEnd: data['availabilityEnd'] as String? ?? '18:00',
      isActive: data['isActive'] as bool? ?? false,
      sigapMataPoints: data['sigapMataPoints'] as int? ?? 0,
      certifications: List<String>.from(data['certifications'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'skills': skills,
      'availabilityStart': availabilityStart,
      'availabilityEnd': availabilityEnd,
      'isActive': isActive,
      'sigapMataPoints': sigapMataPoints,
      'certifications': certifications,
    };
  }

  VolunteerProfileModel copyWith({
    String? uid,
    List<String>? skills,
    String? availabilityStart,
    String? availabilityEnd,
    bool? isActive,
    int? sigapMataPoints,
    List<String>? certifications,
  }) {
    return VolunteerProfileModel(
      uid: uid ?? this.uid,
      skills: skills ?? this.skills,
      availabilityStart: availabilityStart ?? this.availabilityStart,
      availabilityEnd: availabilityEnd ?? this.availabilityEnd,
      isActive: isActive ?? this.isActive,
      sigapMataPoints: sigapMataPoints ?? this.sigapMataPoints,
      certifications: certifications ?? this.certifications,
    );
  }

  @override
  List<Object?> get props =>
      [uid, skills, availabilityStart, availabilityEnd, isActive, sigapMataPoints, certifications];
}

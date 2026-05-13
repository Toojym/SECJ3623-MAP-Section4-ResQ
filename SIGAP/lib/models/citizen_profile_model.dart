import 'package:equatable/equatable.dart';

class CitizenProfileModel extends Equatable {
  final String uid;
  final String fullName;
  final String email;
  final String password;
  final String profileImageUrl;
  final String icNumber;
  final String phoneNumber;
  final String address;
  
  final String emergencyContactName;
  final String emergencyContactPhone;
  
  final bool hasMobilityIssue;
  final String mobilityIssueDesc;
  final bool hasCriticalIllness;
  final String criticalIllnessDesc;
  final bool isPregnant;
  final String pregnantTrimester;
  
  final int householdSize;
  final bool hasPets;
  final List<Map<String, String>> familyMembers;

  const CitizenProfileModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.password,
    required this.profileImageUrl,
    required this.icNumber,
    required this.phoneNumber,
    required this.address,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.hasMobilityIssue,
    required this.mobilityIssueDesc,
    required this.hasCriticalIllness,
    required this.criticalIllnessDesc,
    required this.isPregnant,
    required this.pregnantTrimester,
    required this.householdSize,
    required this.hasPets,
    required this.familyMembers,
  });

  factory CitizenProfileModel.fromFirestore(Map<String, dynamic> data) {
    final members = (data['familyMembers'] as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(e as Map))
            .toList() ??
        [];
        
    return CitizenProfileModel(
      uid: data['uid'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      password: data['password'] as String? ?? '',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      icNumber: data['icNumber'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      
      emergencyContactName: data['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] as String? ?? '',
      
      hasMobilityIssue: data['hasMobilityIssue'] as bool? ?? false,
      mobilityIssueDesc: data['mobilityIssueDesc'] as String? ?? '',
      hasCriticalIllness: data['hasCriticalIllness'] as bool? ?? false,
      criticalIllnessDesc: data['criticalIllnessDesc'] as String? ?? '',
      isPregnant: data['isPregnant'] as bool? ?? false,
      pregnantTrimester: data['pregnantTrimester'] as String? ?? '',
      
      householdSize: data['householdSize'] as int? ?? 1,
      hasPets: data['hasPets'] as bool? ?? false,
      familyMembers: members,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'password': password,
      'profileImageUrl': profileImageUrl,
      'icNumber': icNumber,
      'phoneNumber': phoneNumber,
      'address': address,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'hasMobilityIssue': hasMobilityIssue,
      'mobilityIssueDesc': mobilityIssueDesc,
      'hasCriticalIllness': hasCriticalIllness,
      'criticalIllnessDesc': criticalIllnessDesc,
      'isPregnant': isPregnant,
      'pregnantTrimester': pregnantTrimester,
      'householdSize': householdSize,
      'hasPets': hasPets,
      'familyMembers': familyMembers,
    };
  }

  CitizenProfileModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? password,
    String? profileImageUrl,
    String? icNumber,
    String? phoneNumber,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? hasMobilityIssue,
    String? mobilityIssueDesc,
    bool? hasCriticalIllness,
    String? criticalIllnessDesc,
    bool? isPregnant,
    String? pregnantTrimester,
    int? householdSize,
    bool? hasPets,
    List<Map<String, String>>? familyMembers,
  }) {
    return CitizenProfileModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      icNumber: icNumber ?? this.icNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      hasMobilityIssue: hasMobilityIssue ?? this.hasMobilityIssue,
      mobilityIssueDesc: mobilityIssueDesc ?? this.mobilityIssueDesc,
      hasCriticalIllness: hasCriticalIllness ?? this.hasCriticalIllness,
      criticalIllnessDesc: criticalIllnessDesc ?? this.criticalIllnessDesc,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnantTrimester: pregnantTrimester ?? this.pregnantTrimester,
      householdSize: householdSize ?? this.householdSize,
      hasPets: hasPets ?? this.hasPets,
      familyMembers: familyMembers ?? this.familyMembers,
    );
  }

  @override
  List<Object?> get props => [
        uid, fullName, email, password, profileImageUrl, icNumber, phoneNumber, address,
        emergencyContactName, emergencyContactPhone,
        hasMobilityIssue, mobilityIssueDesc,
        hasCriticalIllness, criticalIllnessDesc,
        isPregnant, pregnantTrimester,
        householdSize, hasPets, familyMembers,
      ];
}

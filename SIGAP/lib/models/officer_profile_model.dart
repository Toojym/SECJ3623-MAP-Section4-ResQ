import 'package:equatable/equatable.dart';

class OfficerProfileModel extends Equatable {
  final String uid;
  final String agencyName;
  final String designation;
  final String badgeNumber;
  final String district;

  const OfficerProfileModel({
    required this.uid,
    required this.agencyName,
    required this.designation,
    required this.badgeNumber,
    required this.district,
  });

  factory OfficerProfileModel.fromFirestore(Map<String, dynamic> data) {
    return OfficerProfileModel(
      uid: data['uid'] as String? ?? '',
      agencyName: data['agencyName'] as String? ?? '',
      designation: data['designation'] as String? ?? '',
      badgeNumber: data['badgeNumber'] as String? ?? '',
      district: data['district'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'agencyName': agencyName,
      'designation': designation,
      'badgeNumber': badgeNumber,
      'district': district,
    };
  }

  OfficerProfileModel copyWith({
    String? uid,
    String? agencyName,
    String? designation,
    String? badgeNumber,
    String? district,
  }) {
    return OfficerProfileModel(
      uid: uid ?? this.uid,
      agencyName: agencyName ?? this.agencyName,
      designation: designation ?? this.designation,
      badgeNumber: badgeNumber ?? this.badgeNumber,
      district: district ?? this.district,
    );
  }

  @override
  List<Object?> get props => [uid, agencyName, designation, badgeNumber, district];
}

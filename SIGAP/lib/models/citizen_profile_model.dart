import 'package:equatable/equatable.dart';

class CitizenProfileModel extends Equatable {
  final String uid;
  final String icNumber;
  final String phoneNumber;
  final String address;
  final int householdSize;
  final List<Map<String, String>> emergencyContacts;

  const CitizenProfileModel({
    required this.uid,
    required this.icNumber,
    required this.phoneNumber,
    required this.address,
    required this.householdSize,
    required this.emergencyContacts,
  });

  factory CitizenProfileModel.fromFirestore(Map<String, dynamic> data) {
    final contacts = (data['emergencyContacts'] as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(e as Map))
            .toList() ??
        [];
    return CitizenProfileModel(
      uid: data['uid'] as String? ?? '',
      icNumber: data['icNumber'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      householdSize: data['householdSize'] as int? ?? 1,
      emergencyContacts: contacts,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'icNumber': icNumber,
      'phoneNumber': phoneNumber,
      'address': address,
      'householdSize': householdSize,
      'emergencyContacts': emergencyContacts,
    };
  }

  CitizenProfileModel copyWith({
    String? uid,
    String? icNumber,
    String? phoneNumber,
    String? address,
    int? householdSize,
    List<Map<String, String>>? emergencyContacts,
  }) {
    return CitizenProfileModel(
      uid: uid ?? this.uid,
      icNumber: icNumber ?? this.icNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      householdSize: householdSize ?? this.householdSize,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  @override
  List<Object?> get props => [uid, icNumber, phoneNumber, address, householdSize, emergencyContacts];
}
